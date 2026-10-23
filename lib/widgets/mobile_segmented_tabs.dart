import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Thanh chọn tab dạng segmented control dùng trên giao diện điện thoại.
class MobileSegmentedTabs extends StatelessWidget {
  const MobileSegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.chip,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: <Widget>[
          for (int index = 0; index < labels.length; index++)
            Expanded(
              child: Semantics(
                button: true,
                selected: selectedIndex == index,
                child: Material(
                  color: selectedIndex == index
                      ? p.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    onTap: () => onChanged(index),
                    borderRadius: BorderRadius.circular(9),
                    child: Center(
                      child: Text(
                        labels[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selectedIndex == index
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selectedIndex == index
                              ? p.textPrimary
                              : p.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
