import 'package:flutter/material.dart';

class LexoraWordmark extends StatelessWidget {
  const LexoraWordmark({
    super.key,
    this.fontSize = 42,
    this.alignment = TextAlign.center,
    this.hero = false,
  });

  final double fontSize;
  final TextAlign alignment;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF7F8FB)
        : const Color(0xFF10131D);
    const mint = Color(0xFF68E6C0);
    const blue = Color(0xFF2444C8);
    final style = TextStyle(
      fontFamily: 'Manrope',
      fontSize: fontSize,
      height: .9,
      fontWeight: FontWeight.w800,
      letterSpacing: -fontSize * (hero ? .12 : .075),
      color: ink,
    );

    return Semantics(
      label: 'Lexora',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            style: style,
            children: [
              const TextSpan(text: 'Le'),
              TextSpan(
                text: 'x',
                style: style.copyWith(color: mint, fontWeight: FontWeight.w900),
              ),
              TextSpan(
                text: 'ora',
                style: style.copyWith(color: blue),
              ),
            ],
          ),
          textAlign: alignment,
          maxLines: 1,
        ),
      ),
    );
  }
}
