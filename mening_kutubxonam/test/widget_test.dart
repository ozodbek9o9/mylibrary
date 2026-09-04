import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mening_kutubxonam/main.dart';

void main() {
  testWidgets('shows library splash screen', (tester) async {
    await tester.pumpWidget(const MyLibrary());
    expect(find.text('Mening Kutubxonam'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
