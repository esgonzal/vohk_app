import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../vohk_theme.dart';

class LiveCameraView extends StatefulWidget {
  final String streamUrl;
  const LiveCameraView({super.key, required this.streamUrl});
  @override
  State<LiveCameraView> createState() => _LiveCameraViewState();
}

class _LiveCameraViewState extends State<LiveCameraView> {
  static const Duration _iceGatheringBudget = Duration(milliseconds: 1200);

  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  Uri? _sessionUri;
  Timer? _reconnectTimer;
  Timer? _healthTimer;
  int _generation = 0;
  int _stalledChecks = 0;
  int _lastBytesReceived = -1;
  bool loadingVideo = true;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _renderer.initialize();
      if (!_disposed) await _startWebRTC();
    } catch (error) {
      debugPrint('WEBRTC INITIALIZATION ERROR: $error');
    }
  }

  @override
  void didUpdateWidget(covariant LiveCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) _restartNow();
  }

  Future<void> _startWebRTC() async {
    final generation = ++_generation;
    await _closeConnection();
    if (_disposed || widget.streamUrl.isEmpty) return;
    if (mounted) setState(() => loadingVideo = true);

    try {
      final config = {
        'iceServers': [
          {
            'urls': ['stun:stun.l.google.com:19302'],
          },
        ],
      };
      final peerConnection = await createPeerConnection(config);
      if (_disposed || generation != _generation) {
        await peerConnection.close();
        return;
      }
      _pc = peerConnection;
      final iceComplete = Completer<void>();
      peerConnection.onIceGatheringState = (state) {
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete && !iceComplete.isCompleted) {
          iceComplete.complete();
        }
      };
      peerConnection.onConnectionState = (state) {
        if (_disposed || generation != _generation) return;
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          _scheduleReconnect(generation, const Duration(seconds: 5));
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed || state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          _scheduleReconnect(generation, const Duration(seconds: 2));
        }
      };
      await peerConnection.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      peerConnection.onTrack = (event) {
        if (event.track.kind == 'audio') {
          event.track.enabled = false;
          unawaited(event.track.stop());
          return;
        }
        if (event.streams.isNotEmpty) {
          final stream = event.streams[0];
          for (final audioTrack in stream.getAudioTracks()) {
            audioTrack.enabled = false;
            audioTrack.stop();
          }
          if (!_disposed && generation == _generation) _renderer.srcObject = stream;
          if (mounted && !_disposed && generation == _generation) {
            setState(() {
              loadingVideo = false;
            });
          }
        }
      };
      final offer = await peerConnection.createOffer();
      if (_disposed || generation != _generation) return;
      await peerConnection.setLocalDescription(offer);
      if (peerConnection.iceGatheringState != RTCIceGatheringState.RTCIceGatheringStateComplete) {
        // Do not make the viewer wait for a slow or unreachable STUN server.
        // Candidates gathered within this short budget are included in the
        // WHEP offer; MediaMTX can start the stream without waiting eight
        // seconds for ICE gathering to report completion.
        await iceComplete.future.timeout(_iceGatheringBudget, onTimeout: () {});
      }
      if (_disposed || generation != _generation) return;
      final localDesc = await peerConnection.getLocalDescription();
      final streamUri = Uri.parse(widget.streamUrl);
      final basePath = streamUri.path.endsWith('/') ? streamUri.path : '${streamUri.path}/';
      final whepUri = streamUri.replace(path: '${basePath}whep');
      final client = HttpClient();
      try {
        final request = await client.postUrl(whepUri);
        request.headers.set('Content-Type', 'application/sdp');
        request.add(utf8.encode(localDesc!.sdp!));
        final response = await request.close();
        final location = response.headers.value(HttpHeaders.locationHeader);
        final body = await response.transform(utf8.decoder).join();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('WHEP failed: ${response.statusCode} $body');
        }
        if (location != null && location.isNotEmpty) {
          var sessionUri = whepUri.resolve(location);
          final token = streamUri.queryParameters['token'];
          if (token != null && !sessionUri.queryParameters.containsKey('token')) {
            sessionUri = sessionUri.replace(queryParameters: {...sessionUri.queryParameters, 'token': token});
          }
          _sessionUri = sessionUri;
        }
        if (_disposed || generation != _generation) return;
        await peerConnection.setRemoteDescription(RTCSessionDescription(body, 'answer'));
      } finally {
        client.close(force: true);
      }
      _startHealthMonitor(generation);
    } catch (e) {
      debugPrint('WEBRTC ERROR: $e');
      if (!_disposed && generation == _generation) {
        _scheduleReconnect(generation, const Duration(seconds: 2));
      }
    }
  }

  void _scheduleReconnect(int generation, Duration delay) {
    if (_disposed || generation != _generation || _reconnectTimer != null) return;
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (!_disposed && generation == _generation) _startWebRTC();
    });
  }

  void _startHealthMonitor(int generation) {
    _healthTimer?.cancel();
    _lastBytesReceived = -1;
    _stalledChecks = 0;
    _healthTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final peerConnection = _pc;
      if (_disposed || generation != _generation || peerConnection == null) return;
      try {
        final reports = await peerConnection.getStats();
        var bytesReceived = 0;
        for (final report in reports) {
          final values = report.values;
          final mediaType = values['kind'] ?? values['mediaType'];
          if (report.type == 'inbound-rtp' && mediaType == 'video') {
            bytesReceived += (values['bytesReceived'] as num?)?.toInt() ?? 0;
          }
        }
        if (bytesReceived > _lastBytesReceived) {
          _lastBytesReceived = bytesReceived;
          _stalledChecks = 0;
        } else if (_lastBytesReceived >= 0 && ++_stalledChecks >= 3) {
          debugPrint('WEBRTC video stopped receiving data; reconnecting ${widget.streamUrl}');
          _scheduleReconnect(generation, Duration.zero);
        } else {
          _lastBytesReceived = bytesReceived;
        }
      } catch (error) {
        debugPrint('WEBRTC stats error: $error');
      }
    });
  }

  void _restartNow() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _startWebRTC();
  }

  Future<void> _closeConnection() async {
    _healthTimer?.cancel();
    _healthTimer = null;
    final sessionUri = _sessionUri;
    _sessionUri = null;
    final stream = _renderer.srcObject;
    _renderer.srcObject = null;
    final peerConnection = _pc;
    _pc = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    }
    if (peerConnection != null) {
      await peerConnection.close();
      await peerConnection.dispose();
    }
    if (sessionUri != null) {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      try {
        final request = await client.deleteUrl(sessionUri);
        final response = await request.close().timeout(const Duration(seconds: 3));
        await response.drain<void>().timeout(const Duration(seconds: 3));
      } catch (error) {
        debugPrint('Could not close WHEP session: $error');
      } finally {
        client.close(force: true);
      }
    }
  }

  Future<void> _disposeRenderer() async {
    try {
      await _renderer.dispose();
    } catch (error) {
      // Some Android devices can destroy the backing texture while a route is
      // being removed. Do not let a native renderer teardown race escape as an
      // unhandled Dart exception.
      debugPrint('WEBRTC renderer cleanup error: $error');
    }
  }

  Future<void> _finishConnectionCleanup(Future<void> cleanup) async {
    try {
      await cleanup;
    } catch (error) {
      debugPrint('WEBRTC connection cleanup error: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _reconnectTimer?.cancel();
    _healthTimer?.cancel();
    // _closeConnection synchronously detaches the stream before its first
    // await. Start renderer disposal immediately, while Flutter still owns the
    // texture, rather than waiting for peer/WHEP cleanup after the route is gone.
    final connectionCleanup = _closeConnection();
    unawaited(_disposeRenderer());
    unawaited(_finishConnectionCleanup(connectionCleanup));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RTCVideoView(_renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain),
          if (loadingVideo) const Center(child: CircularProgressIndicator(color: VohkColors.accent)),
        ],
      ),
    );
  }
}
