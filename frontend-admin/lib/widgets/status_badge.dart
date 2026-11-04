import 'package:flutter/material.dart';

/// A solid-colour pill with white text, always legible no matter which
/// status colour it's showing - a tinted background behind same-hue text
/// (the old approach) can wash out to near-invisible; white-on-solid never
/// does.
class StatusBadge extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.emoji, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
