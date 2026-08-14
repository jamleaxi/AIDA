import 'package:aida/screens/offline_status_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the offline message and image', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OfflineStatusPage(onRetry: () {})),
    );

    expect(find.text("You're offline"), findsOneWidget);
    expect(
      find.text('Check your internet connection and try again.'),
      findsOneWidget,
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('tapping "Try again" calls onRetry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(home: OfflineStatusPage(onRetry: () => retried = true)),
    );

    await tester.tap(find.byKey(const Key('offlineRetryButton')));
    await tester.pump();

    expect(retried, isTrue);
  });
}
