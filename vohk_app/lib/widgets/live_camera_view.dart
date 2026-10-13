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
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  bool loadingVideo = true;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _startWebRTC();
  }

  Future<void> _startWebRTC() async {
    try {
      await _renderer.initialize();
      if (_disposed) return;
      final config = {
        'iceServers': [
          {
            'urls': ['stun:stun.l.google.com:19302'],
          },
        ],
      };
      final peerConnection = await createPeerConnection(config);
      if (_disposed) {
        await peerConnection.close();
        return;
      }
      _pc = peerConnection;
      await peerConnection.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      peerConnection.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          final stream = event.streams[0];
          for (final audioTrack in stream.getAudioTracks()) {
            audioTrack.enabled = false;
            audioTrack.stop();
          }
          if (!_disposed) _renderer.srcObject = stream;
          if (mounted && !_disposed) {
            setState(() {
              loadingVideo = false;
            });
          }
        }
      };
      final offer = await peerConnection.createOffer();
      if (_disposed) return;
      await peerConnection.setLocalDescription(offer);
      await Future.delayed(const Duration(milliseconds: 500));
      if (_disposed) return;
      final localDesc = await peerConnection.getLocalDescription();
      final whepUrl = '${widget.streamUrl}whep';
      final request = await HttpClient().postUrl(Uri.parse(whepUrl));
      request.headers.set('Content-Type', 'application/sdp');
      request.add(utf8.encode(localDesc!.sdp!));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('WHEP failed: ${response.statusCode} $body');
      }
      if (_disposed) return;
      await peerConnection.setRemoteDescription(RTCSessionDescription(body, 'answer'));
    } catch (e) {
      debugPrint('WEBRTC ERROR: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final stream = _renderer.srcObject;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
    }
    _renderer.srcObject = null;
    _pc?.close();
    _pc = null;
    _renderer.dispose();
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
