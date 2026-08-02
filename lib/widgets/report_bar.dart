import 'package:flutter/material.dart';

class ReportBar extends StatelessWidget {
  const ReportBar({
    super.key,
    required this.label,
    required this.value,
    required this.total,
    this.trailing,
  });

  final String label;
  final num value;
  final num total;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0
        ? 0.0
        : (value / total).clamp(0.0, 1.0).toDouble();
    final displayValue = trailing ?? _formatNumber(value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Text(displayValue, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
          ),
        ],
      ),
    );
  }

  String _formatNumber(num number) {
    if (number is double && number != number.roundToDouble()) {
      return number.toStringAsFixed(1);
    }
    return number.toInt().toString();
  }
}
