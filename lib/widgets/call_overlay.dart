import 'dart:async';
import 'package:flutter/material.dart';

import '../data/chat_service.dart';
import '../models/chat_contact.dart';

class CallOverlay extends StatefulWidget {
  const CallOverlay({
    super.key,
    required this.friend,
    required this.isVideo,
    this.isIncoming = false,
    this.onClose,
  });

  final Friend friend;
  final bool isVideo;
  final bool isIncoming;
  final VoidCallback? onClose;

  static void startCall(
    BuildContext context, {
    required Friend friend,
    required bool isVideo,
    bool isIncoming = false,
  }) {
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
          onClose: () => Navigator.of(ctx).pop(),
        );
      },
    );
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

    if (!widget.isIncoming) {
      ChatService.instance.initiateCall(widget.friend.id, isVideo: widget.isVideo);
      Timer(const Duration(milliseconds: 3000), () {
        if (!mounted || _connected) return;
        setState(() => _connected = true);
        _startTimer();
      });
    }

    _callEventsSub = ChatService.instance.callEvents.listen((event) {
      if (!mounted) return;
      final type = event['type']?.toString();
      if (type == 'answered') {
        if (!_connected) {
          setState(() => _connected = true);
          _startTimer();
        }
      } else if (type == 'ended' || type == 'rejected') {
        _hangup();
      }
    });
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  void _answerCall() {
    ChatService.instance.answerCall(widget.friend.id);
    setState(() => _connected = true);
    _startTimer();
  }

  void _hangup() {
    _callTimer?.cancel();
    _callEventsSub?.cancel();
    ChatService.instance.endCall(
      widget.friend.id,
      isVideo: widget.isVideo,
      durationSeconds: _seconds,
    );
    widget.onClose?.call();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _callTimer?.cancel();
    _callEventsSub?.cancel();
    super.dispose();
  }

  String get _timeString {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.isVideo && !_isCameraOff;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Nền cuộc gọi: video nền hoặc gradient ZaloChat mượt mà
          if (isVideo && _connected)
            _buildVideoBackground()
          else
            _buildAudioBackground(),

          // Thông tin người gọi & Trạng thái cuộc gọi
          SafeArea(
            child: Column(
              children: <Widget>[
                const SizedBox(height: 36),
                Text(
                  widget.isVideo ? 'CUỘC GỌI VIDEO ZALOCHAT' : 'CUỘC GỌI THOẠI TIKTUBE',
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
                const Spacer(),

                // Avatar với hiệu ứng sóng âm (Pulse Ring) nếu không phải video
                if (!isVideo || !_connected)
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
                                alpha: (1.3 - _pulseAnimation.value).clamp(0.0, 0.5),
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

                const SizedBox(height: 48),
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

  Widget _buildVideoBackground() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Giả lập khung hình video người nhận
        Container(
          color: const Color(0xFF1A1A2E),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.videocam_rounded, size: 64, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(height: 10),
              Text(
                'Camera HD: ${widget.friend.name}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
        // Khung hình camera bản thân ở góc
        Positioned(
          top: 60,
          right: 20,
          child: Container(
            width: 100,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white70, width: 2),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person, color: Colors.white60, size: 40),
          ),
        ),
      ],
    );
  }

  Widget _buildCallControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          // Nút Mic
          _CircleButton(
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _isMuted ? 'Bật mic' : 'Tắt mic',
            active: _isMuted,
            onTap: () => setState(() => _isMuted = !_isMuted),
          ),

          // Nút Camera (nếu là video call)
          if (widget.isVideo)
            _CircleButton(
              icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
              label: _isCameraOff ? 'Bật cam' : 'Tắt cam',
              active: _isCameraOff,
              onTap: () => setState(() => _isCameraOff = !_isCameraOff),
            ),

          // Nút Loa ngoài
          _CircleButton(
            icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            label: _isSpeakerOn ? 'Loa ngoài' : 'Loa trong',
            active: _isSpeakerOn,
            onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
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

