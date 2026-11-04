import 'package:flutter/material.dart';

/// Wraps a dialog's form fields with consistent spacing and a capped width,
/// so stacked TextFields never visually merge into each other (no gap) and
/// never stretch edge-to-edge on a wide screen - this is the one place that
/// decides dialog form layout, instead of every call site doing it by hand.
Widget dialogForm(List<Widget> fields, {double gap = 14, double maxWidth = 340}) {
  final spaced = <Widget>[];
  for (var i = 0; i < fields.length; i++) {
    spaced.add(fields[i]);
    if (i != fields.length - 1) spaced.add(SizedBox(height: gap));
  }
  return ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Column(mainAxisSize: MainAxisSize.min, children: spaced),
  );
}
