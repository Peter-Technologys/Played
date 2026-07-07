import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../services/media_chat_service.dart';

/// ModernGlassNotificationBanner — in-app floating overlay notification.
///
/// Shows a frosted-glass banner that slides down from below the status bar
/// when a ChatMessage arrives. Automatically dismisses after 4 seconds.
///
/// Performance notes:
///   • Uses Flutter’s Overlay engine stack — no platform channel or
///     native notification plugin needed.
///   • BackdropFilter is wrapped in ClipRRect to prevent blur bleeding
///     outside the rounded corners (a common source of GPU overdraw).
///   • The static ImageFilter is allocated once per class, not per frame.
///   • The dismiss timer is cancelled in dispose() to prevent memory leaks
///     if the widget is removed before the timer fires.
///   • AnimationController is disposed in _BannerState.dispose().
class ModernGlassNotificationBanner {
  ModernGlassNotificationBanner._();

  // Static ImageFilter — allocated once, reused across all banner instances.
  static final _blurFilter = ImageFilter.blur(sigmaX: 12, sigmaY: 12);

  static OverlayEntry? _current;

  /// Show a banner for [message]. If a banner is already visible it is
  /// replaced immediately to avoid stacking.
  static void show(BuildContext context, ChatMessage message) {
    _current?.remove();
    _current = null;

    final entry = OverlayEntry(
      builder: (_) => _BannerWidget(
        message:    message,
        blurFilter: _blurFilter,
        onDismiss:  () {
          _current?.remove();
          _current = null;
        },
      ),
    );
    _current = entry;
    Overlay.of(context).insert(entry);
  }

  /// Manually dismiss the current banner (e.g. when navigating away).
  static void dismiss() {
    _current?.remove();
    _current = null;
  }
}

// ── Banner widget ─────────────────────────────────────────────────────────────────────────

class _BannerWidget extends StatefulWidget {
  final ChatMessage message;
  final ImageFilter blurFilter;
  final VoidCallback onDismiss;

  const _BannerWidget({
    required this.message,
    required this.blurFilter,
    required this.onDismiss,
  });

  @override
  State<_BannerWidget> createState() => _BannerState();
}

class _BannerState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset>   _slide;
  late final Animation<double>   _fade;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 380),
    );
    // Slide in from above the screen
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();

    // Auto-dismiss after 4 seconds — timer is cancelled in dispose()
    // so it cannot fire after the widget is removed from the tree.
    _dismissTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  // Neon border color based on message type
  Color get _accentColor => switch (widget.message.type) {
    ChatMessageType.chatMessage   => AppColors.accent,
    ChatMessageType.transferAlert => AppColors.accentGreen,
    ChatMessageType.systemEvent   => AppColors.accentViolet,
  };

  IconData get _icon => switch (widget.message.type) {
    ChatMessageType.chatMessage   => Icons.chat_bubble_rounded,
    ChatMessageType.transferAlert => Icons.swap_horiz_rounded,
    ChatMessageType.systemEvent   => Icons.info_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      // Place the banner just below the status bar / notch
      top:   topPadding + 8,
      left:  16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap:             _dismiss,
            onVerticalDragEnd: (_) => _dismiss(),
            child: _buildGlassPanel(),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassPanel() {
    final accent = _accentColor;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        // Multi-layer neon glow border shadow
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 8,  spreadRadius: -2),
          BoxShadow(color: accent.withValues(alpha: 0.20), blurRadius: 20, spreadRadius:  0),
          BoxShadow(color: accent.withValues(alpha: 0.08), blurRadius: 40, spreadRadius:  4),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: widget.blurFilter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              // Semi-transparent dark glass surface
              color: const Color(0xFF090D16).withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accent.withValues(alpha: 0.40),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                // Icon badge
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color:  accent.withValues(alpha: 0.12),
                    shape:  BoxShape.circle,
                    border: Border.all(
                        color: accent.withValues(alpha: 0.30), width: 1),
                  ),
                  child: Icon(_icon, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.message.sender,
                        style: TextStyle(
                          fontSize:   12,
                          fontWeight: FontWeight.w700,
                          color:      accent,
                          fontFamily: 'Inter',
                          // fontFamilyFallback ensures emoji render correctly
                          // across all Android API levels.
                          fontFamilyFallback: const ['NotoColorEmoji'],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.message.text,
                        maxLines:  2,
                        overflow:  TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize:   13,
                          color:      AppColors.textPrimary,
                          fontFamily: 'Inter',
                          fontFamilyFallback: ['NotoColorEmoji'],
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Dismiss X
                GestureDetector(
                  onTap: _dismiss,
                  child: Icon(Icons.close_rounded,
                      color: AppColors.textSecondary, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── NotificationListener mixin ───────────────────────────────────────────────────────────────

/// Mixin for any State that wants to auto-show glass banners when a
/// ChatMessage arrives on the MediaChatService stream.
///
/// Usage:
///   class _MyScreenState extends State<MyScreen>
///       with ChatNotificationMixin { ... }
mixin ChatNotificationMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<ChatMessage>? _chatSub;

  @override
  void initState() {
    super.initState();
    _chatSub = MediaChatService.instance.messages.listen((msg) {
      if (!mounted) return;
      ModernGlassNotificationBanner.show(context, msg);
    });
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    super.dispose();
  }
}
