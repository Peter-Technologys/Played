import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import 'modern_neon_container.dart';
import 'modern_neon_text.dart';
import 'glowing_neon_progress_ring.dart';

/// NeonMediaDashboard — integrated premium performance screen.
///
/// Combines all four neon UI components into a single demonstration view.
/// Background: ultra-deep space canvas (#090D16).
///
/// Performance rules applied:
///   • All static shadow/gradient configs are const or final-at-build-time.
///   • RepaintBoundary wraps the progress ring so streaming progress
///     updates never trigger a full-screen repaint.
///   • AnimatedBuilder is used for the progress demo so only the ring
///     subtree rebuilds during animation.
class NeonMediaDashboard extends StatefulWidget {
  /// Optional: pass a real download progress stream from your file
  /// transfer controller. Defaults to an animated demo loop.
  final Stream<double>? progressStream;
  final String          peerName;
  final bool            isConnected;
  final VoidCallback?   onSendTap;
  final VoidCallback?   onReceiveTap;

  const NeonMediaDashboard({
    super.key,
    this.progressStream,
    this.peerName    = 'No device paired',
    this.isConnected = false,
    this.onSendTap,
    this.onReceiveTap,
  });

  @override
  State<NeonMediaDashboard> createState() => _NeonMediaDashboardState();
}

class _NeonMediaDashboardState extends State<NeonMediaDashboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _demoCtrl;
  late final Animation<double>   _demoProgress;

  @override
  void initState() {
    super.initState();
    // Demo animation — only runs when no real progressStream is provided.
    _demoCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _demoProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _demoCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _demoCtrl.dispose();
    super.dispose();
  }

  // ── Static gradient configs ─────────────────────────────────────────────────────────
  static const _titleColors  = [Color(0xFF00D4FF), Color(0xFF7C3AED)];
  static const _sendColors   = [Color(0xFF7C3AED), Color(0xFFEC4899)];
  static const _recvColors   = [Color(0xFF00D4FF), Color(0xFF10B981)];
  static const _ringColors   = [Color(0xFF00D4FF), Color(0xFF7C3AED)];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── TOP HEADER ────────────────────────────────────────────────────────────
              ModernNeonText(
                text:     '⚡ Flash Share',
                fontSize: 32,
                colors:   _titleColors,
              ),
              const SizedBox(height: 4),
              ModernNeonText(
                text:     'Offline P2P • No Internet Needed',
                fontSize: 13,
                colors:   [Color(0xFF5E7399), Color(0xFF5E7399)],
                fontWeight: FontWeight.w500,
              ),
              const SizedBox(height: 24),

              // ── STATUS PANEL ───────────────────────────────────────────────────────────
              ModernNeonContainer(
                neonColor: widget.isConnected
                    ? AppColors.accent
                    : AppColors.textSecondary,
                borderRadius: 18,
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    // Animated pulse dot
                    _PulseDot(active: widget.isConnected),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isConnected ? 'Paired Device' : 'Waiting for device…',
                            style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              letterSpacing: 1.1, fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.peerName,
                            style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary, fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      widget.isConnected
                          ? Icons.wifi_rounded
                          : Icons.wifi_off_rounded,
                      color: widget.isConnected
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      size: 22,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── ACTION MODULE ───────────────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onSendTap,
                      child: ModernNeonContainer(
                        neonColor:    const Color(0xFF7C3AED),
                        borderRadius: 18,
                        padding:      const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (b) => LinearGradient(
                                colors: _sendColors,
                              ).createShader(b),
                              child: const Icon(Icons.upload_rounded,
                                  size: 36, color: Colors.white),
                            ),
                            const SizedBox(height: 10),
                            ModernNeonText(
                              text:     'SEND',
                              fontSize: 16,
                              colors:   _sendColors,
                            ),
                            const SizedBox(height: 4),
                            const Text('Share files',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Inter',
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onReceiveTap,
                      child: ModernNeonContainer(
                        neonColor:    const Color(0xFF00D4FF),
                        borderRadius: 18,
                        padding:      const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (b) => const LinearGradient(
                                colors: _recvColors,
                              ).createShader(b),
                              child: const Icon(Icons.download_rounded,
                                  size: 36, color: Colors.white),
                            ),
                            const SizedBox(height: 10),
                            ModernNeonText(
                              text:     'RECEIVE',
                              fontSize: 16,
                              colors:   _recvColors,
                            ),
                            const SizedBox(height: 4),
                            const Text('Get files',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontFamily: 'Inter',
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── PROGRESS RING ───────────────────────────────────────────────────────────
              ModernNeonContainer(
                neonColor:    const Color(0xFF00D4FF),
                borderRadius: 20,
                padding:      const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('TRANSFER PROGRESS',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.2, fontFamily: 'Inter',
                        )),
                    const SizedBox(height: 20),
                    // RepaintBoundary ensures only the ring repaints
                    // during streaming — the rest of the screen is frozen.
                    RepaintBoundary(
                      child: widget.progressStream != null
                          ? StreamBuilder<double>(
                              stream: widget.progressStream,
                              initialData: 0,
                              builder: (_, snap) => _buildRing(snap.data ?? 0),
                            )
                          : AnimatedBuilder(
                              animation: _demoProgress,
                              builder: (_, __) => _buildRing(_demoProgress.value),
                            ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Waiting for transfer…',
                        style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary,
                          fontFamily: 'Inter',
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRing(double progress) => GlowingNeonProgressRing(
    progress:    progress,
    size:        160,
    strokeWidth: 10,
    colors:      _ringColors,
    centerChild: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${(progress * 100).toStringAsFixed(0)}%',
          style: const TextStyle(
            fontSize: 28, fontWeight: FontWeight.w800,
            color: AppColors.textPrimary, fontFamily: 'Inter',
          ),
        ),
        const Text('complete',
            style: TextStyle(
              fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Inter')),
      ],
    ),
  );
}

// ── Animated pulse dot ───────────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final bool active;
  const _PulseDot({required this.active});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.active) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.active) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? AppColors.accent : AppColors.textSecondary;
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: widget.active
              ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)]
              : null,
        ),
      ),
    );
  }
}
