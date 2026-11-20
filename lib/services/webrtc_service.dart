import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Dịch vụ truyền tải âm thanh & hình ảnh trực tiếp qua giao thức WebRTC (P2P Live Audio & Video)
/// Sử dụng cụm STUN Server của Google để kết nối trực tiếp camera, micro và loa giữa 2 thiết bị.
class WebRtcService {
  WebRtcService._();
  static final WebRtcService instance = WebRtcService._();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  /// Renderers hiển thị video trên giao diện
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool _renderersInitialized = false;

  bool isLocalVideoReady = false;
  bool isRemoteVideoReady = false;

  /// Hàng đợi ứng viên ICE Candidate nếu đến trước khi setRemoteDescription
  final List<RTCIceCandidate> _pendingCandidates = [];

  /// Callback khi có thay đổi trạng thái luồng video/âm thanh
  VoidCallback? onStreamUpdate;

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

  /// Khởi tạo các bộ giải mã hiển thị video
  Future<void> initRenderers() async {
    if (!_renderersInitialized) {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      _renderersInitialized = true;
    }
  }

  /// Thu thập luồng camera & microphone với cơ chế dự phòng 3 lớp
  Future<MediaStream?> _getUserMediaWithFallback({required bool isVideo}) async {
    if (!isVideo) {
      return await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': true,
        'video': false,
      });
    }

    // Lớp 1: Thử camera trước với facingMode chuẩn
    try {
      final stream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': true,
        'video': <String, dynamic>{
          'facingMode': 'user',
        },
      });
      if (stream.getVideoTracks().isNotEmpty) {
        return stream;
      }
    } catch (e) {
      debugPrint('[WebRTC] getUserMedia facingMode user không thành công: $e');
    }

    // Lớp 2: Thử video: true cơ bản
    try {
      final stream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': true,
        'video': true,
      });
      if (stream.getVideoTracks().isNotEmpty) {
        return stream;
      }
    } catch (e) {
      debugPrint('[WebRTC] getUserMedia video:true không thành công: $e');
    }

    // Lớp 3: Dự phòng chỉ audio nếu camera bị lỗi phần cứng
    try {
      return await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': true,
        'video': false,
      });
    } catch (e) {
      debugPrint('[WebRTC] getUserMedia audio:true thất bại: $e');
      return null;
    }
  }

  /// Khởi tạo cuộc gọi từ phía người gọi (Caller): Mở mic & camera, tạo SDP Offer kèm Google STUN
  Future<Map<String, dynamic>?> createOffer({bool isVideo = false}) async {
    try {
      await initRenderers();
      await disposeCall();

      _peerConnection = await createPeerConnection(_iceServers);

      // Thu luồng micro và camera thực tế từ thiết bị
      _localStream = await _getUserMediaWithFallback(isVideo: isVideo);
      if (_localStream != null) {
        localRenderer.srcObject = _localStream;
        isLocalVideoReady = isVideo && _localStream!.getVideoTracks().isNotEmpty;
        onStreamUpdate?.call();

        for (final track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
      }

      // Nhận luồng âm thanh và video từ đối phương
      _peerConnection!.onTrack = (RTCTrackEvent event) async {
        debugPrint('[WebRTC] Nhận track: kind=${event.track.kind}, streams=${event.streams.length}');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
        } else {
          _remoteStream ??= await createLocalMediaStream('remote_stream');
          _remoteStream!.addTrack(event.track);
        }
        remoteRenderer.srcObject = _remoteStream;
        if (event.track.kind == 'video' || _remoteStream!.getVideoTracks().isNotEmpty) {
          isRemoteVideoReady = true;
        }
        onStreamUpdate?.call();
      };

      _peerConnection!.onAddStream = (MediaStream stream) {
        debugPrint('[WebRTC] Nhận onAddStream: id=${stream.id}');
        _remoteStream = stream;
        remoteRenderer.srcObject = _remoteStream;
        isRemoteVideoReady = stream.getVideoTracks().isNotEmpty;
        onStreamUpdate?.call();
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
        'offerToReceiveVideo': isVideo ? 1 : 0,
      });
      await _peerConnection!.setLocalDescription(offer);

      // Chờ tối đa 1.5 giây để gom ứng viên STUN Google vào SDP (Vanilla ICE)
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
      debugPrint('[WebRTC] Lỗi tạo Offer: $e');
      return null;
    }
  }

  /// Phía người nhận (Receiver) trả lời: Nạp Offer, mở micro & camera, tạo SDP Answer
  Future<Map<String, dynamic>?> createAnswer(
    Map<String, dynamic> offerMap, {
    bool isVideo = false,
  }) async {
    try {
      await initRenderers();
      await disposeCall();

      _peerConnection = await createPeerConnection(_iceServers);

      // Mở micro & camera của máy người nhận
      _localStream = await _getUserMediaWithFallback(isVideo: isVideo);
      if (_localStream != null) {
        localRenderer.srcObject = _localStream;
        isLocalVideoReady = isVideo && _localStream!.getVideoTracks().isNotEmpty;
        onStreamUpdate?.call();

        for (final track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
      }

      // Nhận luồng âm thanh và video từ máy người gọi
      _peerConnection!.onTrack = (RTCTrackEvent event) async {
        debugPrint('[WebRTC] Nhận track: kind=${event.track.kind}, streams=${event.streams.length}');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
        } else {
          _remoteStream ??= await createLocalMediaStream('remote_stream');
          _remoteStream!.addTrack(event.track);
        }
        remoteRenderer.srcObject = _remoteStream;
        if (event.track.kind == 'video' || _remoteStream!.getVideoTracks().isNotEmpty) {
          isRemoteVideoReady = true;
        }
        onStreamUpdate?.call();
      };

      _peerConnection!.onAddStream = (MediaStream stream) {
        debugPrint('[WebRTC] Nhận onAddStream: id=${stream.id}');
        _remoteStream = stream;
        remoteRenderer.srcObject = _remoteStream;
        isRemoteVideoReady = stream.getVideoTracks().isNotEmpty;
        onStreamUpdate?.call();
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
        // Xả hàng đợi ICE candidates
        for (final candidate in _pendingCandidates) {
          try {
            await _peerConnection!.addCandidate(candidate);
          } catch (_) {}
        }
        _pendingCandidates.clear();
      }

      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': isVideo ? 1 : 0,
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
      debugPrint('[WebRTC] Lỗi tạo Answer: $e');
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

        // Xả hàng đợi ICE candidates nếu có
        for (final candidate in _pendingCandidates) {
          try {
            await _peerConnection!.addCandidate(candidate);
          } catch (_) {}
        }
        _pendingCandidates.clear();
      }
    } catch (e) {
      debugPrint('[WebRTC] Lỗi setRemoteAnswer: $e');
    }
  }

  /// Thêm ứng viên ICE Candidate từ đối phương
  Future<void> addCandidate(Map<String, dynamic> candidateMap) async {
    try {
      final candidateStr = candidateMap['candidate']?.toString();
      final sdpMid = candidateMap['sdpMid']?.toString();
      final rawIndex = candidateMap['sdpMLineIndex'];
      final sdpMLineIndex = rawIndex is int
          ? rawIndex
          : int.tryParse(rawIndex?.toString() ?? '0') ?? 0;

      if (candidateStr != null && candidateStr.isNotEmpty) {
        final rtcCandidate = RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex);
        if (_peerConnection == null) {
          _pendingCandidates.add(rtcCandidate);
          return;
        }
        final remoteDesc = await _peerConnection!.getRemoteDescription();
        if (remoteDesc == null) {
          _pendingCandidates.add(rtcCandidate);
        } else {
          await _peerConnection!.addCandidate(rtcCandidate);
        }
      }
    } catch (e) {
      debugPrint('[WebRTC] Lỗi addCandidate: $e');
    }
  }

  /// Đổi giữa Camera trước và sau
  Future<void> switchCamera() async {
    try {
      final videoTracks = _localStream?.getVideoTracks();
      if (videoTracks != null && videoTracks.isNotEmpty) {
        await Helper.switchCamera(videoTracks.first);
        onStreamUpdate?.call();
      }
    } catch (e) {
      debugPrint('[WebRTC] Lỗi switchCamera: $e');
    }
  }

  /// Bật / Tắt Camera của máy
  void setCameraEnabled(bool enabled) {
    try {
      final videoTracks = _localStream?.getVideoTracks();
      if (videoTracks != null) {
        for (final track in videoTracks) {
          track.enabled = enabled;
        }
        isLocalVideoReady = enabled;
        onStreamUpdate?.call();
      }
    } catch (e) {
      debugPrint('[WebRTC] Lỗi setCameraEnabled: $e');
    }
  }

  /// Bật / Tắt Micro của máy
  void setMicrophoneMute(bool muted) {
    try {
      final audioTracks = _localStream?.getAudioTracks();
      if (audioTracks != null) {
        for (final track in audioTracks) {
          track.enabled = !muted;
        }
      }
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
      _pendingCandidates.clear();
      isLocalVideoReady = false;
      isRemoteVideoReady = false;

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

      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;

      await _peerConnection?.close();
      await _peerConnection?.dispose();
      _peerConnection = null;
      debugPrint('[WebRTC] Đã giải phóng hoàn tất tài nguyên cuộc gọi');
    } catch (e) {
      debugPrint('[WebRTC] Lỗi disposeCall: $e');
    }
  }
}
