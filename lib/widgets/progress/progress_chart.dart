import 'package:flutter/material.dart';

class ProgressChart extends StatelessWidget {
  const ProgressChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(0.7, 'Mon'),
              _buildBar(0.9, 'Tue'),
              _buildBar(0.6, 'Wed'),
              _buildBar(0.8, 'Thu'),
              _buildBar(0.95, 'Fri'),
              _buildBar(0.5, 'Sat'),
              _buildBar(0.3, 'Sun'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Weekly Study Time',
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    );
  }

  Widget _buildBar(double percentage, String label) {
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: constraints.maxHeight * percentage,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
