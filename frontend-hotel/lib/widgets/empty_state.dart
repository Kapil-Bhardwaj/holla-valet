import 'package:flutter/material.dart';
import 'glass_card.dart';

/// A blank column is confusing mid-shift - this always explains what's
/// (not) happening, inside a soft frosted-glass panel instead of a flat,
/// empty space.
class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;

  const EmptyState({super.key, required this.emoji, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GlassCard(
          padding: const EdgeInsets.all(18),
          borderRadius: 18,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
