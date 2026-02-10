import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
  });

  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).clamp(0, 100).round();
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          SizedBox(
            height: size,
            width: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 10, // mais fino e elegante
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                scheme.primary,
              ),
            ),
          ),

          // Conteúdo central
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: size * 0.16, // proporcional ao ring
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'do jejum',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      fontSize: size * 0.10,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
