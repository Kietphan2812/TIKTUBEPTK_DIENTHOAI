import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TikTubeLogo extends StatelessWidget {
  const TikTubeLogo({super.key, this.showText = true, this.scale = 1});

  final bool showText;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 38 * scale,
          height: 27 * scale,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFFFF2D45), Color(0xFFD10E28)],
            ),
            borderRadius: BorderRadius.circular(5 * scale),
          ),
          child: Text(
            'PTK',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12 * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3 * scale,
              height: 1,
            ),
          ),
        ),
        if (showText) ...<Widget>[
          SizedBox(width: 7 * scale),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: 'TIK', style: TextStyle(color: p.brandRed)),
                TextSpan(text: 'TUBE', style: TextStyle(color: p.textPrimary)),
              ],
            ),
            style: TextStyle(
              fontSize: 21 * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8 * scale,
              height: 1,
            ),
          ),
        ],
      ],
    );
  }
}
