import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config.dart';
import 'locale.dart';

// Family colour band, see DESIGN.md. Same values as packages/shared/src/band.ts:
// glow for gradient surfaces and dark backgrounds, deep for text on light ones.
const glow = [
  Color(0xFFF2545B),
  Color(0xFFFB8C45),
  Color(0xFFF2C14E),
  Color(0xFF6CCF8E),
  Color(0xFF46BFE0),
  Color(0xFF8E92F8),
  Color(0xFFC39BF2),
];
const deep = [
  Color(0xFFB3262D),
  Color(0xFFA8461A),
  Color(0xFF876008),
  Color(0xFF1D6A44),
  Color(0xFF156A88),
  Color(0xFF3B3EA8),
  Color(0xFF6A33A0),
];

const paper = Color(0xFFF4F4F1);
const ink = Color(0xFF17171A);
const muted = Color(0xFF5E5E66);
const hairline = Color(0x2917171A);

// Signal colours, see DESIGN.md: the same in every product, never the product colour.
// Filled counters take glow with ink text, text and lines on paper take deep.
const needsGlow = Color(0xFFF4B44C);
const needsDeep = Color(0xFF8F5A0C);
const newGlow = Color(0xFF6CCF8E);
const newDeep = Color(0xFF1D6A44);
const errorGlow = Color(0xFFF2545B);
const errorDeep = Color(0xFFB3262D);
const displayFont = 'Bricolage Grotesque';
const _radius = BorderRadius.all(Radius.circular(8));

/// Colour at a position from 1 to 7, linear between neighbouring stages.
Color bandColor(double position, List<Color> tones) {
  final p = position.clamp(1.0, 7.0);
  final i = math.min(5, (p - 1).floor());
  return Color.lerp(tones[i], tones[i + 1], p - 1 - i)!;
}

/// Gradient of this app's section, from bottom left to top right.
LinearGradient bandGradient(List<Color> tones) => LinearGradient(
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
  colors: [
    bandColor(appBand.from, tones),
    bandColor((appBand.from + appBand.to) / 2, tones),
    bandColor(appBand.to, tones),
  ],
);

ThemeData buildTheme() {
  final accent = bandColor((appBand.from + appBand.to) / 2, deep);
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: accent, primary: accent, error: errorDeep, surface: paper, onSurface: ink),
    scaffoldBackgroundColor: paper,
  );
  TextStyle? display(TextStyle? style) => style?.copyWith(
    fontFamily: displayFont,
    fontWeight: FontWeight.w700,
    fontVariations: const [FontVariation('wdth', 80), FontVariation('wght', 750)],
  );
  final text = base.textTheme;
  return base.copyWith(
    textTheme: text.copyWith(
      displayLarge: display(text.displayLarge),
      displayMedium: display(text.displayMedium),
      displaySmall: display(text.displaySmall),
      headlineLarge: display(text.headlineLarge),
      headlineMedium: display(text.headlineMedium),
      headlineSmall: display(text.headlineSmall),
      titleLarge: display(text.titleLarge),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: paper, foregroundColor: ink),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: const WidgetStatePropertyAll(ink),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: _radius)),
        backgroundBuilder: (context, states, child) => Opacity(
          opacity: states.contains(WidgetState.disabled) ? 0.5 : 1,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: bandGradient(glow), borderRadius: _radius),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// Sender line at the bottom of a screen: made by Pleasance, signed with the
/// wordmark over the family band that marks where this app sits, and the
/// language button.
class PleasanceFooter extends ConsumerWidget {
  const PleasanceFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(messagesProvider);
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: muted);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: hairline)),
        ),
        child: Row(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.madeBy,
                  style: const TextStyle(
                    color: muted,
                    fontFamily: displayFont,
                    fontSize: 14,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    fontVariations: [FontVariation('wdth', 80), FontVariation('wght', 650)],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SvgPicture.asset(
                      'assets/pleasance-wordmark.svg',
                      width: _signatureWidth,
                      height: 11,
                      colorFilter: const ColorFilter.mode(muted, BlendMode.srcIn),
                      semanticsLabel: 'Pleasance',
                    ),
                    const SizedBox(height: 4),
                    const _BandLine(),
                  ],
                ),
              ],
            ),
            const Spacer(),
            TextButton(
              onPressed: () => ref.read(localeProvider.notifier).toggle(),
              style: TextButton.styleFrom(
                foregroundColor: muted,
                textStyle: small,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(t.otherLanguage),
            ),
          ],
        ),
      ),
    );
  }
}

// Width of the wordmark at 11 high, the band below spans exactly that.
const _signatureWidth = 99.0;

class _BandLine extends StatelessWidget {
  const _BandLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _signatureWidth,
      height: 4,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 1,
            height: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(1)),
                gradient: LinearGradient(colors: [for (final c in glow) Color.lerp(c, Colors.white, 0.6)!]),
              ),
            ),
          ),
          Positioned(
            left: _signatureWidth * (appBand.from - 1) / 6,
            top: 0,
            width: math.max(6, _signatureWidth * (appBand.to - appBand.from) / 6),
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: bandGradient(glow),
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
