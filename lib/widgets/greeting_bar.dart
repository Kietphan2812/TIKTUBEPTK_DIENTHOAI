import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GreetingBar extends StatelessWidget {
  const GreetingBar({super.key, this.name = 'kiepthan4', this.onTap});

  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Row(
      children: <Widget>[
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: p.border),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: p.shadow,
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.chip,
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 17,
                      color: p.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Xin chào, $name',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
