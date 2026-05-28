import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

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
  @override
  void initState() {
    super.initState();
    _startWebRTC();
  }

  Future<void> _startWebRTC() async {
    try {
      await _renderer.initialize();
      final config = {
        'iceServers': [
          {
            'urls': ['stun:stun.l.google.com:19302'],
          },
        ],
      };
      _pc = await createPeerConnection(config);
      await _pc!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      _pc!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          _renderer.srcObject = event.streams[0];
          if (mounted) {
            setState(() {
              loadingVideo = false;
            });
          }
        }
      };
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      await Future.delayed(const Duration(milliseconds: 500));
      final localDesc = await _pc!.getLocalDescription();
      final whepUrl = '${widget.streamUrl}/whep';
      final request = await HttpClient().postUrl(Uri.parse(whepUrl));
      request.headers.set('Content-Type', 'application/sdp');
      request.add(utf8.encode(localDesc!.sdp!));
      final response = await request.close();
      if (response.statusCode != 201) {
        throw Exception('WHEP failed: ${response.statusCode}');
      }
      final answerSdp = await response.transform(utf8.decoder).join();
      await _pc!.setRemoteDescription(
        RTCSessionDescription(answerSdp, 'answer'),
      );
    } catch (e) {
      debugPrint('WEBRTC ERROR: $e');
    }
  }

  @override
  void dispose() {
    _renderer.dispose();
    _pc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RTCVideoView(
          _renderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
        ),
        if (loadingVideo) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
