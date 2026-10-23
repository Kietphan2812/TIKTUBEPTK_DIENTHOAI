import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DataLoading extends StatelessWidget {
  const DataLoading({super.key, this.message = 'Đang tải dữ liệu từ Neon...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: p.brandRed,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: TextStyle(fontSize: 11.5, color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

class DataError extends StatelessWidget {
  const DataError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.cloud_off_rounded, size: 34, color: p.textSecondary),
          const SizedBox(height: 12),
          Text(
            'Không tải được dữ liệu từ Neon',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: p.textSecondary),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: p.textPrimary,
              side: BorderSide(color: p.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}
