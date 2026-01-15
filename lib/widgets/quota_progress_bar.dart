import 'package:flutter/material.dart';

class QuotaProgressBar extends StatelessWidget {
  final double value; // 0.0 ~ 2.0+
  final String label;

  const QuotaProgressBar({
    super.key,
    required this.value,
    required this.label,
  });

  Color _getColor() {
    if (value < 0.5) return Colors.green;
    if (value < 0.75) return Colors.yellow.shade700;
    if (value < 1.0) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: _getColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (value > 1.0)
                FractionallySizedBox(
                  widthFactor: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.withOpacity(0.6), Colors.red],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}