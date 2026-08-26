import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/duplicate_detector_service.dart';
import '../../../core/services/storage_analyzer_service.dart';

// Top-level function required by compute() — closures cannot cross isolate
// boundaries, so the entry point must be a top-level or static function.
List<List<String>> _findDuplicatesIsolate(List<TrackMeta> tracks) =>
    DuplicateDetectorService.instance.findDuplicates(tracks);

class StorageAnalyzerScreen extends StatefulWidget {
  const StorageAnalyzerScreen({super.key});
  @override State<StorageAnalyzerScreen> createState() => _State();
}

class _State extends State<StorageAnalyzerScreen>
    with SingleTickerProviderStateMixin {
  StorageReport? _report;
  bool  _loading = true;
  bool  _purging = false;
  int?  _freed;
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;
  // Guard against concurrent analyze() calls (e.g. rapid refresh taps).
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _load();
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (_analyzing) return;
    _analyzing = true;
    setState(() { _loading = true; _freed = null; });
    try {
      final r = await StorageAnalyzerService.instance.analyze();
      if (!mounted) return;
      setState(() { _report = r; _loading = false; });
      _ctrl.forward(from: 0);
    } finally {
      _analyzing = false;
    }
  }

  Future<void> _purge() async {
    setState(() => _purging = true);
    final f = await StorageAnalyzerService.instance.purgeCache();
    if (!mounted) return;
    setState(() { _purging = false; _freed = f; });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background, elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Storage',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary, fontFamily: 'Inter')),
        actions: [IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 22),
          onPressed: _loading ? null : _load,
        )],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final r = _report!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => _RingChart(report: r, progress: _anim.value),
          ),
          const SizedBox(height: 24),
          _legend(r),
          const SizedBox(height: 16),
          _purgeCard(r),
          if (_freed != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 20),
                const SizedBox(width: 10),
                Text('Freed ${r.fmt(_freed!)}',
                    style: const TextStyle(color: AppColors.accentGreen,
                        fontWeight: FontWeight.w600, fontFamily: 'Inter', fontSize: 13)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _legend(StorageReport r) {
    final items = [
      ('Videos', r.videoBytes, const Color(0xFF00D4FF)),
      ('Audio',  r.audioBytes, const Color(0xFF7C3AED)),
      ('Cache',  r.cacheBytes, const Color(0xFFF59E0B)),
      ('Other',  r.otherBytes, const Color(0xFF5E7399)),
      ('Free',   r.freeBytes,  const Color(0xFF10B981)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Container(width: 12, height: 12,
                decoration: BoxDecoration(color: item.$3, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(item.$1,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Inter'))),
            Text(r.fmt(item.$2),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary, fontFamily: 'Inter')),
          ]),
        )).toList(),
      ),
    );
  }

  Widget _purgeCard(StorageReport r) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
              color: AppColors.accentAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.cleaning_services_rounded,
              color: AppColors.accentAmber, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Clear Cache', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary, fontFamily: 'Inter')),
          Text('${r.fmt(r.cacheBytes)} can be freed',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Inter')),
        ])),
        ElevatedButton(
          onPressed: _purging ? null : _purge,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentAmber, foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _purging
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Clear', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Inter')),
        ),
      ]),
    );
  }
}

class _RingChart extends StatelessWidget {
  final StorageReport report;
  final double        progress;
  const _RingChart({required this.report, required this.progress});
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(width: 220, height: 220,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: const Size(220, 220),
            painter: _RingPainter(report: report, progress: progress)),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(report.fmt(report.usedBytes),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary, fontFamily: 'Inter')),
          const Text('used', style: TextStyle(fontSize: 12,
              color: AppColors.textSecondary, fontFamily: 'Inter')),
          const SizedBox(height: 4),
          Text('of ${report.fmt(report.totalBytes)}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'Inter')),
        ]),
      ]),
    ),
  );
}

class _RingPainter extends CustomPainter {
  final StorageReport report;
  final double        progress;
  static const _colors = [
    Color(0xFF00D4FF), Color(0xFF7C3AED),
    Color(0xFFF59E0B), Color(0xFF5E7399), Color(0xFF10B981),
  ];
  const _RingPainter({required this.report, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const sw     = 22.0;
    final radius = (size.width - sw) / 2;
    final rect   = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(center, radius, Paint()
      ..style = PaintingStyle.stroke..strokeWidth = sw
      ..color = Colors.white.withValues(alpha: 0.05));
    final total = report.totalBytes.toDouble();
    if (total <= 0) return;
    final vals = [report.videoBytes, report.audioBytes,
        report.cacheBytes, report.otherBytes, report.freeBytes];
    double angle = -math.pi / 2;
    const gap = 0.015;
    for (var i = 0; i < vals.length; i++) {
      final sweep = 2 * math.pi * (vals[i] / total) * progress;
      if (sweep < 0.01) { angle += sweep; continue; }
      canvas.drawArc(rect, angle + gap / 2, sweep - gap, false,
          Paint()..style = PaintingStyle.stroke..strokeWidth = sw
              ..strokeCap = StrokeCap.round..color = _colors[i]);
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.progress != progress || o.report != report;
}
