import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Dịch vụ truyền tải âm thanh & giọng nói trực tiếp qua giao thức WebRTC (P2P Live Audio)
/// Sử dụng cụm STUN Server của Google để kết nối trực tiếp micro và loa giữa 2 thiết bị.
class WebRtcService {
  WebRtcService._();
  static final WebRtcService instance = WebRtcService._();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  /// Callback khi sinh ra ứng viên mạng ICE Candidate mới
  Function(Map<String, dynamic> candidate)? onIceCandidateGenerated;

  // Cụm máy chủ STUN miễn phí chất lượng cao của Google
  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  static const Map<String, dynamic> _mediaConstraints = {
    'audio': true,
    'video': false,
  };

  /// Khởi tạo cuộc gọi từ phía người gọi (Caller): Lấy microphone, tạo SDP Offer kèm Google STUN
  Future<Map<String, dynamic>?> createOffer() async {
    try {
      await disposeCall();

      _peerConnection = await createPeerConnection(_iceServers);

      // Thu âm micro của máy thực tế
      _localStream = await navigator.mediaDevices.getUserMedia(_mediaConstraints);
      for (final track in _localStream!.getAudioTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      // Nhận luồng âm thanh từ micro đối phương và phát trực tiếp ra loa
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'audio') {
          debugPrint('[WebRTC] Đã kết nối luồng âm thanh đàm thoại từ đối phương!');
          _remoteStream = event.streams.isNotEmpty ? event.streams[0] : null;
        }
      };

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
          onIceCandidateGenerated?.call({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          });
        }
      };

      final iceCompleter = Completer<void>();
      _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
            !iceCompleter.isCompleted) {
          iceCompleter.complete();
        }
      };

      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });
      await _peerConnection!.setLocalDescription(offer);

      // Chờ tối đa 1.5 giây để gom toàn bộ ứng viên STUN Google vào SDP (Vanilla ICE)
      await iceCompleter.future.timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () {},
      );

      final completeDesc = await _peerConnection!.getLocalDescription();
      final finalOffer = completeDesc ?? offer;

      // Mặc định bật loa ngoài
      Helper.setSpeakerphoneOn(true);

      return {
        'sdp': finalOffer.sdp,
        'type': finalOffer.type,
      };
    } catch (e) {
      debugPrint('[WebRTC] Lỗi tạo Offer âm thanh: $e');
      return null;
    }
  }

  /// Phía người nhận (Receiver) trả lời: Nạp Offer, mở microphone, tạo SDP Answer
  Future<Map<String, dynamic>?> createAnswer(Map<String, dynamic> offerMap) async {
    try {
      await disposeCall();

      _peerConnection = await createPeerConnection(_iceServers);

      // Mở micro của máy người nhận
      _localStream = await navigator.mediaDevices.getUserMedia(_mediaConstraints);
      for (final track in _localStream!.getAudioTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      // Nhận luồng âm thanh từ máy người gọi
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'audio') {
          debugPrint('[WebRTC] Đã kết nối luồng âm thanh đàm thoại từ đối phương!');
          _remoteStream = event.streams.isNotEmpty ? event.streams[0] : null;
        }
      };

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
          onIceCandidateGenerated?.call({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          });
        }
      };

      final iceCompleter = Completer<void>();
      _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
            !iceCompleter.isCompleted) {
          iceCompleter.complete();
        }
      };

      final sdp = offerMap['sdp']?.toString() ?? '';
      final type = offerMap['type']?.toString() ?? 'offer';
      if (sdp.isNotEmpty) {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(sdp, type),
        );
      }

      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });
      await _peerConnection!.setLocalDescription(answer);

      // Chờ STUN thu thập xong ứng viên
      await iceCompleter.future.timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () {},
      );

      final completeDesc = await _peerConnection!.getLocalDescription();
      final finalAnswer = completeDesc ?? answer;

      Helper.setSpeakerphoneOn(true);

      return {
        'sdp': finalAnswer.sdp,
        'type': finalAnswer.type,
      };
    } catch (e) {
      debugPrint('[WebRTC] Lỗi tạo Answer âm thanh: $e');
      return null;
    }
  }

  /// Nạp SDP Answer từ người nhận vào máy người gọi để thông tuyến
  Future<void> setRemoteAnswer(Map<String, dynamic> answerMap) async {
    try {
      if (_peerConnection == null) return;
      final sdp = answerMap['sdp']?.toString() ?? '';
      final type = answerMap['type']?.toString() ?? 'answer';
      if (sdp.isNotEmpty) {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(sdp, type),
        );
        debugPrint('[WebRTC] Đã thiết lập thông tuyến Remote Answer thành công!');
      }
    } catch (e) {
      debugPrint('[WebRTC] Lỗi setRemoteAnswer: $e');
    }
  }

  /// Thêm ứng viên ICE Candidate từ đối phương
  Future<void> addCandidate(Map<String, dynamic> candidateMap) async {
    try {
      if (_peerConnection == null) return;
      final candidateStr = candidateMap['candidate']?.toString();
      final sdpMid = candidateMap['sdpMid']?.toString();
      final rawIndex = candidateMap['sdpMLineIndex'];
      final sdpMLineIndex = rawIndex is int
          ? rawIndex
          : int.tryParse(rawIndex?.toString() ?? '0') ?? 0;

      if (candidateStr != null && candidateStr.isNotEmpty) {
        await _peerConnection!.addCandidate(
          RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex),
        );
      }
    } catch (e) {
      debugPrint('[WebRTC] Lỗi addCandidate: $e');
    }
  }

  /// Bật / Tắt Micro của máy
  void setMicrophoneMute(bool muted) {
    try {
      _localStream?.getAudioTracks().forEach((track) {
        track.enabled = !muted;
      });
      debugPrint('[WebRTC] Micro: ${muted ? "Đã tắt" : "Đã bật"}');
    } catch (e) {
      debugPrint('[WebRTC] Lỗi setMicrophoneMute: $e');
    }
  }

  /// Bật / Tắt Loa ngoài (Speakerphone)
  void setSpeakerphoneOn(bool enabled) {
    try {
      Helper.setSpeakerphoneOn(enabled);
      debugPrint('[WebRTC] Loa ngoài: $enabled');
    } catch (e) {
      debugPrint('[WebRTC] Lỗi setSpeakerphoneOn: $e');
    }
  }

  /// Giải phóng toàn bộ tài nguyên WebRTC khi kết thúc cuộc gọi
  Future<void> disposeCall() async {
    try {
      onIceCandidateGenerated = null;
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      await _localStream?.dispose();
      _localStream = null;

      _remoteStream?.getTracks().forEach((track) {
        track.stop();
      });
      await _remoteStream?.dispose();
      _remoteStream = null;

      await _peerConnection?.close();
      await _peerConnection?.dispose();
      _peerConnection = null;
      debugPrint('[WebRTC] Đã giải phóng hoàn tất tài nguyên cuộc gọi');
    } catch (e) {
      debugPrint('[WebRTC] Lỗi disposeCall: $e');
    }
  }
}

