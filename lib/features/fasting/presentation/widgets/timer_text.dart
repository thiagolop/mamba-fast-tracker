import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TimerText extends StatelessWidget {
  const TimerText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
      textAlign: TextAlign.center,
    );
  }
}
