import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Écran de félicitations pour un nouveau record : animation + vibration.
Future<void> showPrCelebration(BuildContext context, List<PrEvent> events) async {
  if (events.isEmpty) return;
  HapticFeedback.heavyImpact();
  Future.delayed(const Duration(milliseconds: 160), HapticFeedback.mediumImpact);
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (ctx, a1, a2) => _PrDialog(events: events),
    transitionBuilder: (ctx, anim, a2, child) {
      if (MediaQuery.of(ctx).disableAnimations) return child;
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack), child: child),
      );
    },
  );
}

class _PrDialog extends StatefulWidget {
  final List<PrEvent> events;
  const _PrDialog({required this.events});

  @override
  State<_PrDialog> createState() => _PrDialogState();
}

class _PrDialogState extends State<_PrDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  late final List<_Bit> _bits;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    _bits = List.generate(
        24, (i) => _Bit(r.nextDouble(), r.nextDouble() * .35, i % 3, r.nextDouble() * 6 + 2));
    _anim.forward();
    _timer = Timer(const Duration(seconds: 6), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  String _delta(PrEvent e) {
    final p = e.previous;
    if (p == null) return 'Premier résultat enregistré';
    return switch (e.unit) {
      'kg' => '+${fmtNum(e.value - p)} kg sur ton ancien record',
      'reps' => '+${(e.value - p).round()} reps sur ton ancien record',
      _ => '−${fmtTime(p - e.value)} sur ton ancien record',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reduce = MediaQuery.of(context).disableAnimations;
    final first = widget.events.first;
    final rest = widget.events.skip(1).toList();
    final colors = [cs.primary, adaptColor(context), goodColor(context)];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Stack(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 18),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: cs.primaryContainer,
                    child: Icon(Icons.emoji_events, size: 38, color: cs.onPrimaryContainer),
                  ),
                  const SizedBox(height: 12),
                  Text('NOUVEAU RECORD PERSONNEL',
                      style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(first.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(fmtValue(first.value, first.unit),
                      style: TextStyle(
                          fontSize: 56, fontWeight: FontWeight.w800, color: cs.primary, height: 1.1)),
                  Text(_delta(first),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: goodColor(context), fontWeight: FontWeight.w700)),
                  if (rest.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Et aussi : ${rest.map((e) => '${e.name} ${fmtValue(e.value, e.unit)}').join(', ')}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Bien joué')),
                  ),
                ]),
              ),
              if (!reduce)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _Confetti(_anim, _bits, colors)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Bit {
  final double x;
  final double delay;
  final int color;
  final double spin;
  const _Bit(this.x, this.delay, this.color, this.spin);
}

class _Confetti extends CustomPainter {
  final Animation<double> anim;
  final List<_Bit> bits;
  final List<Color> colors;
  _Confetti(this.anim, this.bits, this.colors) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final b in bits) {
      final t = ((anim.value - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final y = -16 + t * (size.height + 32);
      final x = b.x * size.width + math.sin(t * 6 + b.x * 10) * 10;
      paint.color = colors[b.color].withAlpha(((1 - t) * 255).round());
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * b.spin);
      canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -7, 8, 14), const Radius.circular(2)),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _Confetti oldDelegate) => false;
}
