import 'package:flutter/material.dart';

void showAppSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final color = isError
      ? Theme.of(context).colorScheme.error
      : Theme.of(context).colorScheme.primary;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: color,
    ),
  );
}
