import 'package:flutter/material.dart';

Future<void> showLoading(BuildContext context) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: CircularProgressIndicator(color: Colors.red),
    ),
  );
  await Future.delayed(const Duration(milliseconds: 1500));
  if (context.mounted) {
    Navigator.of(context).pop();
  }
}
