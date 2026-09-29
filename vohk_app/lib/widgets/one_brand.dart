import 'package:flutter/material.dart';

import '../vohk_theme.dart';

/// Canonical ONE connector mark, rendered directly from the supplied artwork.
class OneMark extends StatelessWidget {
  final double size;

  const OneMark({super.key, this.size = 52});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'One',
    image: true,
    child: Image.asset('assets/images/one-mark.png', width: size, height: size, fit: BoxFit.contain, filterQuality: FilterQuality.high),
  );
}

class OneWordmark extends StatelessWidget {
  final double height;
  final bool showByVohk;

  const OneWordmark({super.key, this.height = 52, this.showByVohk = true});

  @override
  Widget build(BuildContext context) {
    final oneFontSize = height * .86;
    return Semantics(
      label: 'ONE by VÖHK',
      image: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            OneMark(size: height),
            SizedBox(width: height * .13),
            Text(
              'ONE',
              style: TextStyle(height: .9, color: VohkColors.textPrimary, fontSize: oneFontSize, fontWeight: FontWeight.w300, letterSpacing: -oneFontSize * .065),
            ),
            if (showByVohk) ...[
              SizedBox(width: height * .18),
              Padding(
                padding: EdgeInsets.only(bottom: height * .04),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: VohkColors.textSecondary, fontSize: height * .15),
                    children: [
                      const TextSpan(text: 'by  '),
                      TextSpan(
                        text: 'VÖHK',
                        style: TextStyle(color: VohkColors.textPrimary, fontSize: height * .18, fontWeight: FontWeight.w800, letterSpacing: -.3),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
