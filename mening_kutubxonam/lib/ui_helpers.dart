import 'package:flutter/material.dart';

Future<void> showLoading(BuildContext context) {
  if (!context.mounted) return Future.value();

  showDialog(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) =>
        const Center(child: CircularProgressIndicator(color: Colors.red)),
  );

  return Future.value();
}
