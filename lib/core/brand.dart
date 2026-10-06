import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import 'locale.dart';
import 'messages.dart';

// Pleasance family colour band, see DESIGN.md in the starter: glow for
// gradient surfaces and dark backgrounds, deep for text on light ones.
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
const soft = Color(0x0D17171A);
const displayFont = 'Bricolage Grotesque';

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

/// Middle of the section in deep, for text links on paper.
final accent = bandColor((appBand.from + appBand.to) / 2, deep);

/// Narrow, heavy display style for the name, headings and large numbers.
TextStyle display(double size, {Color? color}) => TextStyle(
  fontFamily: displayFont,
  fontSize: size,
  fontWeight: FontWeight.w700,
  fontVariations: const [FontVariation('wdth', 80), FontVariation('wght', 750)],
  letterSpacing: -0.02 * size,
  height: 1.05,
  color: color,
);

/// Dark tile with the fahrbar mark.
class FahrbarTile extends StatelessWidget {
  const FahrbarTile({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/fahrbar-tile.svg',
    width: size,
    height: size,
    semanticsLabel: 'fahrbar',
  );
}

/// Sender line at the bottom of a screen: made by Pleasance and where this
/// app sits on the family band, and the language button.
class PleasanceFooter extends ConsumerWidget {
  const PleasanceFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: muted);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: const BoxDecoration(
          color: paper,
          border: Border(top: BorderSide(color: hairline)),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: () => launchUrl(Uri.parse('https://pleasance.org')),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.t.madeBy, style: small),
                  const SizedBox(width: 8),
                  SvgPicture.asset(
                    'assets/pleasance-wordmark.svg',
                    height: 13,
                    colorFilter: const ColorFilter.mode(muted, BlendMode.srcIn),
                    semanticsLabel: 'Pleasance',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                heightFactor: 1,
                child: _BandLine(),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => ref.read(localeProvider.notifier).toggle(),
              style: TextButton.styleFrom(
                foregroundColor: muted,
                textStyle: small,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(context.t.otherLanguage),
            ),
          ],
        ),
      ),
    );
  }
}

class _BandLine extends StatelessWidget {
  const _BandLine();

  @override
  Widget build(BuildContext context) {
    // 120 wide, narrower when the footer runs out of room
    return SizedBox(
      width: 120,
      height: 9,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 3,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                  gradient: LinearGradient(
                    colors: [
                      for (final c in glow) Color.lerp(c, Colors.white, 0.6)!,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: constraints.maxWidth * (appBand.from - 1) / 6,
              top: 0,
              width: math.max(
                9,
                constraints.maxWidth * (appBand.to - appBand.from) / 6,
              ),
              height: 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: bandGradient(glow),
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                  boxShadow: const [BoxShadow(color: paper, spreadRadius: 2)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small status chip with a leading dot. Neutral on purpose: red is the
/// brand here, so it must not read as an error.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.dot,
    this.dimmed = false,
  });
  final String label;
  final Widget dot;
  final bool dimmed;

  static Widget filled(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
  static Widget ring() => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: muted, width: 1.5),
    ),
  );
  static Widget gradient() => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      gradient: bandGradient(glow),
      shape: BoxShape.circle,
    ),
  );
  static Widget dash() => Container(width: 8, height: 2, color: muted);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        border: Border.all(color: hairline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: dimmed ? muted : ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Error text with an icon, so it does not look like the brand red alone.
class ErrorLine extends StatelessWidget {
  const ErrorLine(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.error_outline, size: 16, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(message, style: TextStyle(color: color, fontSize: 13)),
        ),
      ],
    );
  }
}
