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
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackHeader = textScale >= 1.3 || constraints.maxWidth < 320;

        final header = stackHeader
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayValue,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      displayValue,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              );

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 7),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(99),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatNumber(num number) {
    if (number is double && number != number.roundToDouble()) {
      return number.toStringAsFixed(1);
    }
    return number.toInt().toString();
  }
}
