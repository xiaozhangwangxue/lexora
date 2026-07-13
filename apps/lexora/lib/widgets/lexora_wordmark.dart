import 'package:flutter/material.dart';

class LexoraWordmark extends StatelessWidget {
  const LexoraWordmark({
    super.key,
    this.fontSize = 42,
    this.alignment = TextAlign.center,
  });

  final double fontSize;
  final TextAlign alignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontFamily: 'Manrope',
      fontSize: fontSize,
      height: .9,
      fontWeight: FontWeight.w800,
      letterSpacing: -fontSize * .065,
      color: scheme.onSurface,
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
                style: style.copyWith(
                  color: scheme.tertiary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: 'ora',
                style: style.copyWith(color: scheme.primary),
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
