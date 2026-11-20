import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../data/chat_service.dart';
import '../models/chat_contact.dart';
import '../services/call_manager.dart';
import '../services/webrtc_service.dart';

class CallOverlay extends StatefulWidget {
  const CallOverlay({
    super.key,
    required this.friend,
    required this.isVideo,
    this.isIncoming = false,
    this.offer,
    this.onClose,
  });

  final Friend friend;
  final bool isVideo;
  final bool isIncoming;
  final Map<String, dynamic>? offer;
  final VoidCallback? onClose;

  static bool _isOpen = false;
  static bool get isCallOpen => _isOpen;

  static void startCall(
    BuildContext context, {
    required Friend friend,
    required bool isVideo,
    bool isIncoming = false,
    Map<String, dynamic>? offer,
  }) {
    if (_isOpen) return;
    _isOpen = true;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return CallOverlay(
          friend: friend,
          isVideo: isVideo,
          isIncoming: isIncoming,
          offer: offer,
          onClose: () {
            _isOpen = false;
            if (Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
          },
        );
      },
    ).then((_) {
      _isOpen = false;
    });
  }

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  Timer? _callTimer;
  StreamSubscription<Map<String, dynamic>>? _callEventsSub;
  int _seconds = 0;
  bool _connected = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _isSwappedView = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Lắng nghe cập nhật luồng WebRTC để vẽ lại giao diện
    WebRtcService.instance.onStreamUpdate = () {
      if (mounted) setState(() {});
    };

    unawaited(_initCall());

    _callEventsSub = ChatService.instance.callEvents.listen((event) {
      if (!mounted) return;
      final type = event['type']?.toString();
      if (type == 'answered') {
        _callTimer?.cancel();
        if (!_connected) {
          setState(() => _connected = true);
          final answer = event['data']?['answer'] is Map
              ? Map<String, dynamic>.from(event['data']['answer'] as Map)
              : null;
          if (answer != null) {
            unawaited(WebRtcService.instance.setRemoteAnswer(answer));
          }
          _startTimer();
        }
      } else if (type == 'ice-candidate') {
        final candidate = event['data']?['candidate'] is Map
            ? Map<String, dynamic>.from(event['data']['candidate'] as Map)
            : null;
        if (candidate != null) {
          unawaited(WebRtcService.instance.addCandidate(candidate));
        }
      } else if (type == 'rejected') {
        _callTimer?.cancel();
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Người nhận đã từ chối cuộc gọi'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        _hangup();
      } else if (type == 'ended') {
        _callTimer?.cancel();
        _hangup();
      }
    });
  }

  Future<void> _initCall() async {
    // 1. Yêu cầu quyền Camera & Micro trên Android
    try {
      const platform = MethodChannel('com.example.flutter_app_ptk/app_control');
      await platform.invokeMethod('requestCallPermissions');
    } catch (_) {}

    // 2. Khởi tạo renderers WebRTC
    await WebRtcService.instance.initRenderers();

    // 3. Nếu là cuộc gọi đến: đổ chuông
    if (widget.isIncoming && !_connected) {
      unawaited(CallManager.instance.startRingtone());
    }

    // 4. Nếu là người gọi: thiết lập WebRTC caller ngay
    if (!widget.isIncoming) {
      await _setupWebRtcCaller();
    }
  }

  Future<void> _setupWebRtcCaller() async {
    WebRtcService.instance.onIceCandidateGenerated = (candidate) {
      ChatService.instance.sendIceCandidate(widget.friend.id, candidate);
    };

    final offer = await WebRtcService.instance.createOffer(isVideo: widget.isVideo);
    if (!mounted) return;

    ChatService.instance.initiateCall(
      widget.friend.id,
      isVideo: widget.isVideo,
      offer: offer,
    );

    // Tự động kết thúc nếu đối phương không nhấc máy sau 45 giây
    _callTimer = Timer(const Duration(seconds: 45), () {
      if (!mounted || _connected) return;
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Người nhận hiện không trả lời'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      _hangup();
    });
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  void _answerCall() async {
    unawaited(CallManager.instance.stopRingtone());

    WebRtcService.instance.onIceCandidateGenerated = (candidate) {
      ChatService.instance.sendIceCandidate(widget.friend.id, candidate);
    };

    Map<String, dynamic>? answer;
    if (widget.offer != null) {
      answer = await WebRtcService.instance.createAnswer(
        widget.offer!,
        isVideo: widget.isVideo,
      );
    } else {
      answer = await WebRtcService.instance.createOffer(isVideo: widget.isVideo);
    }

    if (!mounted) return;
    ChatService.instance.answerCall(widget.friend.id, answer: answer);
    setState(() => _connected = true);
    _startTimer();
  }

  void _hangup() {
    unawaited(CallManager.instance.stopRingtone());
    _callTimer?.cancel();
    _callEventsSub?.cancel();
    WebRtcService.instance.onStreamUpdate = null;
    unawaited(WebRtcService.instance.disposeCall());
    ChatService.instance.endCall(
      widget.friend.id,
      isVideo: widget.isVideo,
      durationSeconds: _seconds,
    );
    widget.onClose?.call();
  }

  @override
  void dispose() {
    unawaited(CallManager.instance.stopRingtone());
    _pulseController.dispose();
    _callTimer?.cancel();
    _callEventsSub?.cancel();
    WebRtcService.instance.onStreamUpdate = null;
    unawaited(WebRtcService.instance.disposeCall());
    super.dispose();
  }

  String get _timeString {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isVideoMode = widget.isVideo && (_connected || !widget.isIncoming);

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Nền cuộc gọi: Luồng Video thực tế 2 chiều hoặc gradient thoại
          if (isVideoMode)
            _buildVideoBackground()
          else
            _buildAudioBackground(),

          // Thông tin người gọi & Trạng thái cuộc gọi
          SafeArea(
            child: Column(
              children: <Widget>[
                const SizedBox(height: 36),
                Text(
                  widget.isVideo
                      ? 'CUỘC GỌI VIDEO TIKTUBE'
                      : 'CUỘC GỌI THOẠI TIKTUBE',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.friend.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.isIncoming && !_connected
                      ? 'Cuộc gọi đến từ ${widget.friend.phone}'
                      : _connected
                          ? _timeString
                          : 'Đang đổ chuông...',
                  style: TextStyle(
                    color: _connected ? const Color(0xFF4CAF50) : Colors.white60,
                    fontSize: _connected ? 18 : 14,
                    fontWeight: _connected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),

                // Trạng thái mic / loa thực tế
                if (_connected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          _isMuted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          size: 14,
                          color: _isMuted
                              ? const Color(0xFFFF2D45)
                              : const Color(0xFF4CAF50),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isMuted
                              ? 'Micro đã tắt'
                              : (_isSpeakerOn
                                  ? 'Loa ngoài • Micro mở'
                                  : 'Loa trong • Micro mở'),
                          style: TextStyle(
                            color: _isMuted
                                ? const Color(0xFFFF2D45)
                                : Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),

                // Avatar với hiệu ứng sóng âm (Pulse Ring) nếu là gọi thoại
                if (!widget.isVideo)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Container(
                            width: 130 * _pulseAnimation.value,
                            height: 130 * _pulseAnimation.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF2D45).withValues(
                                alpha: (1.3 - _pulseAnimation.value)
                                    .clamp(0.0, 0.5),
                              ),
                            ),
                          ),
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF2D45), Color(0xFFD10E28)],
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              widget.friend.name.isNotEmpty
                                  ? widget.friend.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                const Spacer(),

                // Thanh điều khiển cuộc gọi
                if (widget.isIncoming && !_connected)
                  _buildIncomingActions()
                else
                  _buildCallControls(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF0D1B2A),
            Color(0xFF1B263B),
            Color(0xFF0A0F1D),
          ],
        ),
      ),
    );
  }

  /// Giao diện truyền hình ảnh trực tiếp 2 chiều WebRTC
  Widget _buildVideoBackground() {
    final webrtc = WebRtcService.instance;
    final isRemoteAvailable = webrtc.isRemoteVideoReady;
    final isLocalAvailable = webrtc.isLocalVideoReady && !_isCameraOff;

    final showRemoteAsMain = !_isSwappedView;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // 1. Luồng video chính toàn màn hình
        if (showRemoteAsMain) ...[
          if (isRemoteAvailable)
            RTCVideoView(
              webrtc.remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            _buildWaitingRemoteVideoView()
        ] else ...[
          if (isLocalAvailable)
            RTCVideoView(
              webrtc.localRenderer,
              mirror: true,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            _buildCameraOffPlaceholder()
        ],

        // Lớp gradient mỏng để bảo đảm chữ và nút điều khiển luôn rõ nét
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withValues(alpha: 0.65),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.8),
              ],
              stops: const [0.0, 0.28, 0.65, 1.0],
            ),
          ),
        ),

        // 2. Khung hình thu nhỏ góc trên bên phải (PIP - Chạm để hoán đổi góc nhìn)
        Positioned(
          top: 60,
          right: 20,
          child: GestureDetector(
            onTap: () {
              setState(() => _isSwappedView = !_isSwappedView);
            },
            child: Container(
              width: 110,
              height: 155,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFF2D45).withValues(alpha: 0.85),
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (!showRemoteAsMain) ...[
                      if (isRemoteAvailable)
                        RTCVideoView(
                          webrtc.remoteRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      else
                        _buildPipAvatar(widget.friend.name, 'Đối phương')
                    ] else ...[
                      if (isLocalAvailable)
                        RTCVideoView(
                          webrtc.localRenderer,
                          mirror: true,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      else
                        _buildPipCameraOff()
                    ],

                    // Nhãn chỉ dẫn nhỏ
                    Positioned(
                      bottom: 4,
                      left: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          showRemoteAsMain ? 'Bạn (Chạm đổi)' : widget.friend.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingRemoteVideoView() {
    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 90 * _pulseAnimation.value,
                height: 90 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF2D45).withValues(
                    alpha: (1.3 - _pulseAnimation.value).clamp(0.0, 0.4),
                  ),
                ),
                alignment: Alignment.center,
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFFFF2D45),
                  child: Text(
                    widget.friend.name.isNotEmpty
                        ? widget.friend.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Đang kết nối video với ${widget.friend.name}...',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Đang truyền tải hình ảnh HD qua WebRTC',
            style: TextStyle(
              color: Color(0xFF4CAF50),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraOffPlaceholder() {
    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          Icon(Icons.videocam_off_rounded, size: 64, color: Colors.white38),
          SizedBox(height: 12),
          Text(
            'Camera của bạn đã tắt',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipAvatar(String name, String label) {
    return Container(
      color: const Color(0xFF1E293B),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFFF2D45),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipCameraOff() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const <Widget>[
          Icon(Icons.videocam_off_rounded, size: 32, color: Colors.white54),
          SizedBox(height: 6),
          Text(
            'Cam tắt',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          // Nút Mic
          _CircleButton(
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _isMuted ? 'Bật mic' : 'Tắt mic',
            active: _isMuted,
            onTap: () {
              setState(() {
                _isMuted = !_isMuted;
                WebRtcService.instance.setMicrophoneMute(_isMuted);
              });
            },
          ),

          // Nút Bật/Tắt Camera (nếu là video call)
          if (widget.isVideo)
            _CircleButton(
              icon: _isCameraOff
                  ? Icons.videocam_off_rounded
                  : Icons.videocam_rounded,
              label: _isCameraOff ? 'Bật cam' : 'Tắt cam',
              active: _isCameraOff,
              onTap: () {
                setState(() {
                  _isCameraOff = !_isCameraOff;
                  WebRtcService.instance.setCameraEnabled(!_isCameraOff);
                });
              },
            ),

          // Nút Đổi Camera trước / sau (nếu là video call)
          if (widget.isVideo)
            _CircleButton(
              icon: Icons.flip_camera_ios_rounded,
              label: 'Đổi cam',
              active: false,
              onTap: () async {
                await WebRtcService.instance.switchCamera();
                if (mounted) setState(() {});
              },
            ),

          // Nút Loa ngoài
          _CircleButton(
            icon: _isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            label: _isSpeakerOn ? 'Loa ngoài' : 'Loa trong',
            active: _isSpeakerOn,
            onTap: () {
              setState(() {
                _isSpeakerOn = !_isSpeakerOn;
                WebRtcService.instance.setSpeakerphoneOn(_isSpeakerOn);
              });
            },
          ),

          // Nút Gác máy
          _CircleButton(
            icon: Icons.call_end_rounded,
            label: 'Kết thúc',
            color: const Color(0xFFE8112D),
            iconColor: Colors.white,
            onTap: _hangup,
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Nút Từ chối
          _CircleButton(
            icon: Icons.call_end_rounded,
            label: 'Từ chối',
            color: const Color(0xFFE8112D),
            iconColor: Colors.white,
            size: 64,
            onTap: _hangup,
          ),

          // Nút Bắt máy
          _CircleButton(
            icon: Icons.call_rounded,
            label: 'Trả lời',
            color: const Color(0xFF00C853),
            iconColor: Colors.white,
            size: 64,
            onTap: _answerCall,
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.iconColor,
    this.active = false,
    this.size = 54,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Color? iconColor;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bgColor = color ??
        (active ? Colors.white : Colors.white.withValues(alpha: 0.2));
    final fgColor = iconColor ?? (active ? Colors.black : Colors.white);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: fgColor, size: size * 0.48),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
