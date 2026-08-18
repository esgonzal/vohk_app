import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart';

import 'api_config.dart';
import 'auth_service.dart';

enum IntercomTalkState { idle, connecting, active, stopping, failed }

class IntercomTalkService {
  static const int _sampleRate = 8000;
  static const int _bufferSize = 1024;
  static const MethodChannel _androidPcmPlayer = MethodChannel('cl.vohk.comunidades/intercom_pcm_player');

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder(logLevel: Level.warning);
  final FlutterSoundPlayer _player = FlutterSoundPlayer(logLevel: Level.warning, voiceProcessing: true);
  final ValueNotifier<IntercomTalkState> state = ValueNotifier(IntercomTalkState.idle);

  AudioSession? _audioSession;
  WebSocket? _socket;
  StreamSubscription? _socketSubscription;
  StreamController<Uint8List>? _microphoneController;
  StreamSubscription<Uint8List>? _microphoneSubscription;
  Completer<void>? _readyCompleter;
  bool _audioOpen = false;
  bool _stopping = false;

  String? lastError;

  Future<void> start(String deviceId) async {
    if (state.value == IntercomTalkState.connecting || state.value == IntercomTalkState.active) return;
    final token = AuthService.jwt;
    if (token == null || token.isEmpty) throw Exception('La sesión ha expirado. Inicia sesión nuevamente.');
    if (deviceId.isEmpty) throw Exception('El videoportero no tiene device_id.');

    lastError = null;
    _stopping = false;
    state.value = IntercomTalkState.connecting;
    _readyCompleter = Completer<void>();

    try {
      await _openAudio();
      final socket = await WebSocket.connect(ApiConfig.intercomTalkUri(deviceId).toString(), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
      socket.pingInterval = const Duration(seconds: 20);
      _socket = socket;
      _socketSubscription = socket.listen(
        _handleSocketData,
        onError: (Object error, StackTrace stackTrace) => _handleSocketFailure(error),
        onDone: _handleSocketClosed,
        cancelOnError: false,
      );

      await _readyCompleter!.future.timeout(const Duration(seconds: 20));
      await _startMicrophone();
      state.value = IntercomTalkState.active;
    } catch (error, stackTrace) {
      debugPrint('INTERCOM TALK START ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      lastError = _friendlyError(error);
      await _releaseResources();
      state.value = IntercomTalkState.failed;
      throw Exception(lastError);
    }
  }

  Future<void> stop() async {
    if (_stopping || state.value == IntercomTalkState.idle) return;
    _stopping = true;
    state.value = IntercomTalkState.stopping;
    await _releaseResources();
    _stopping = false;
    state.value = IntercomTalkState.idle;
  }

  Future<void> _openAudio() async {
    final session = await AudioSession.instance;
    _audioSession = session;
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker | AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(contentType: AndroidAudioContentType.speech, usage: AndroidAudioUsage.voiceCommunication),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ),
    );
    await session.setActive(true);
    _audioOpen = true;
    await _recorder.openRecorder();
    if (Platform.isAndroid) {
      await _androidPcmPlayer.invokeMethod<void>('open', {'sampleRate': _sampleRate});
    } else {
      await _player.openPlayer();
      await _player.startPlayerFromStream(codec: Codec.pcm16, interleaved: true, numChannels: 1, sampleRate: _sampleRate, bufferSize: _bufferSize);
    }
  }

  Future<void> _startMicrophone() async {
    final controller = StreamController<Uint8List>();
    _microphoneController = controller;
    _microphoneSubscription = controller.stream.listen((pcm) {
      if (pcm.isEmpty || _socket?.readyState != WebSocket.open) return;
      _socket!.add(pcm);
    });
    await _recorder.startRecorder(
      codec: Codec.pcm16,
      toStream: controller.sink,
      sampleRate: _sampleRate,
      numChannels: 1,
      bufferSize: _bufferSize,
      enableVoiceProcessing: true,
      enableNoiseSuppression: true,
      enableEchoCancellation: true,
    );
  }

  void _handleSocketData(dynamic data) {
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is! Map) return;
      switch (decoded['type']) {
        case 'ready':
          if (!(_readyCompleter?.isCompleted ?? true)) _readyCompleter!.complete();
          break;
        case 'error':
          final error = Exception(decoded['message']?.toString() ?? 'El audio del videoportero falló.');
          if (!(_readyCompleter?.isCompleted ?? true)) _readyCompleter!.completeError(error);
          _handleSocketFailure(error);
          break;
      }
      return;
    }

    if (data is List<int> && data.length >= 2 && _audioOpen) {
      final pcm = Uint8List.fromList(data);
      if (Platform.isAndroid) {
        unawaited(_androidPcmPlayer.invokeMethod<void>('write', pcm).catchError((Object error) => _handleSocketFailure(error)));
      } else {
        _player.uint8ListSink?.add(pcm);
      }
    }
  }

  void _handleSocketFailure(Object error) {
    if (_stopping || state.value == IntercomTalkState.idle) return;
    lastError = _friendlyError(error);
    if (!(_readyCompleter?.isCompleted ?? true)) _readyCompleter!.completeError(error);
    if (state.value == IntercomTalkState.connecting) return;
    unawaited(_failAndRelease());
  }

  void _handleSocketClosed() {
    if (_stopping || state.value == IntercomTalkState.idle) return;
    _handleSocketFailure(Exception('La conexión de audio se cerró.'));
  }

  Future<void> _failAndRelease() async {
    if (_stopping) return;
    _stopping = true;
    await _releaseResources();
    _stopping = false;
    state.value = IntercomTalkState.failed;
  }

  Future<void> _releaseResources() async {
    if (_recorder.isRecording) await _recorder.stopRecorder().catchError((_) => null);
    await _microphoneSubscription?.cancel();
    _microphoneSubscription = null;
    await _microphoneController?.close();
    _microphoneController = null;

    final socket = _socket;
    _socket = null;
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await socket?.close(WebSocketStatus.normalClosure, 'Talk ended').catchError((_) => null);

    if (_audioOpen) {
      if (Platform.isAndroid) {
        await _androidPcmPlayer.invokeMethod<void>('close').catchError((_) => null);
      } else {
        await _player.stopPlayer().catchError((_) => null);
        await _player.closePlayer().catchError((_) => null);
      }
      await _recorder.closeRecorder().catchError((_) => null);
      _audioOpen = false;
    }
    await _audioSession?.setActive(false).catchError((_) => false);
    _audioSession = null;
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('401')) return 'La sesión ha expirado. Inicia sesión nuevamente.';
    if (message.contains('403')) return 'No tienes permiso para usar este videoportero.';
    if (message.contains('409')) return 'El audio de este videoportero ya está siendo utilizado.';
    return message;
  }

  Future<void> dispose() async {
    await stop();
    state.dispose();
  }
}
