import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../data/chat_service.dart';
import '../models/chat_contact.dart';
import '../services/call_manager.dart';

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

  static bool _isOpen = false;
  static bool get isCallOpen => _isOpen;

  static void startCall(
    BuildContext context, {
    required Friend friend,
    required bool isVideo,
    bool isIncoming = false,
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

  // Quản lý Camera thiết bị thật
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = <CameraDescription>[];
  bool _isCameraInitialized = false;
  bool _isSwitchingCamera = false;
  int _selectedCameraIndex = 0;

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

    if (widget.isIncoming && !_connected) {
      unawaited(CallManager.instance.startRingtone());
    }

    if (!widget.isIncoming) {
      ChatService.instance.initiateCall(widget.friend.id, isVideo: widget.isVideo);
      Timer(const Duration(milliseconds: 3000), () {
        if (!mounted || _connected) return;
        setState(() => _connected = true);
        if (widget.isVideo) {
          unawaited(_initCamera());
        }
        _startTimer();
      });
    }

    _callEventsSub = ChatService.instance.callEvents.listen((event) {
      if (!mounted) return;
      final type = event['type']?.toString();
      if (type == 'answered') {
        if (!_connected) {
          setState(() => _connected = true);
          if (widget.isVideo) {
            unawaited(_initCamera());
          }
          _startTimer();
        }
      } else if (type == 'ended' || type == 'rejected') {
        _hangup();
      }
    });

    if (widget.isVideo && !widget.isIncoming) {
      unawaited(_initCamera());
    }
  }

  Future<void> _initCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) return;

      int frontIndex = _availableCameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _selectedCameraIndex = (frontIndex != -1) ? frontIndex : 0;
      await _setupCameraController(_availableCameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('[CallOverlay] Lỗi khởi tạo camera: $e');
    }
  }

  Future<void> _setupCameraController(CameraDescription camera) async {
    final prevController = _cameraController;
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
      });
      await prevController?.dispose();
    } catch (e) {
      debugPrint('[CallOverlay] Lỗi setup camera controller: $e');
      await controller.dispose();
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2 || _isSwitchingCamera) return;
    setState(() => _isSwitchingCamera = true);
    try {
      _selectedCameraIndex =
          (_selectedCameraIndex + 1) % _availableCameras.length;
      await _setupCameraController(_availableCameras[_selectedCameraIndex]);
    } finally {
      if (mounted) {
        setState(() => _isSwitchingCamera = false);
      }
    }
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  void _answerCall() {
    unawaited(CallManager.instance.stopRingtone());
    ChatService.instance.answerCall(widget.friend.id);
    setState(() => _connected = true);
    if (widget.isVideo && !_isCameraInitialized) {
      unawaited(_initCamera());
    }
    _startTimer();
  }

  void _hangup() {
    unawaited(CallManager.instance.stopRingtone());
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
    unawaited(CallManager.instance.stopRingtone());
    _pulseController.dispose();
    _callTimer?.cancel();
    _callEventsSub?.cancel();
    _cameraController?.dispose();
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
          // Nền cuộc gọi: Luồng Camera thực tế hoặc gradient thoại mượt mà
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

                // Trạng thái mic / camera thực tế
                if (_connected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
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

  Widget _buildVideoBackground() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Luồng Camera thực tế của thiết bị
        if (_cameraController != null &&
            _isCameraInitialized &&
            !_isCameraOff)
          ClipRect(
            child: OverflowBox(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          )
        else
          Container(
            color: const Color(0xFF0F172A),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  _isCameraOff
                      ? Icons.videocam_off_rounded
                      : Icons.camera_enhance_rounded,
                  size: 64,
                  color: Colors.white38,
                ),
                const SizedBox(height: 12),
                Text(
                  _isCameraOff
                      ? 'Camera đã tắt'
                      : 'Đang kết nối camera thiết bị...',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        // Lớp gradient mỏng để thông tin và các nút luôn sắc nét
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

        // Khung hình thu nhỏ của người nhận (Góc trên bên phải)
        Positioned(
          top: 60,
          right: 20,
          child: Container(
            width: 110,
            height: 155,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFF2D45).withValues(alpha: 0.8),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFFF2D45),
                  child: Text(
                    widget.friend.name.isNotEmpty
                        ? widget.friend.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    widget.friend.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.mic, size: 12, color: Color(0xFF4CAF50)),
                    SizedBox(width: 4),
                    Text(
                      'HD Audio',
                      style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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
            onTap: () => setState(() => _isMuted = !_isMuted),
          ),

          // Nút Camera (nếu là video call)
          if (widget.isVideo)
            _CircleButton(
              icon: _isCameraOff
                  ? Icons.videocam_off_rounded
                  : Icons.videocam_rounded,
              label: _isCameraOff ? 'Bật cam' : 'Tắt cam',
              active: _isCameraOff,
              onTap: () => setState(() => _isCameraOff = !_isCameraOff),
            ),

          // Nút Đổi Camera trước / sau (nếu máy có từ 2 camera)
          if (widget.isVideo && _availableCameras.length > 1)
            _CircleButton(
              icon: Icons.flip_camera_ios_rounded,
              label: 'Đổi cam',
              active: false,
              onTap: _switchCamera,
            ),

          // Nút Loa ngoài
          _CircleButton(
            icon: _isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
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
