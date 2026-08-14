import 'package:aida/models/chat_message.dart';
import 'package:aida/models/user_profile.dart';
import 'package:aida/screens/chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders a single bubble at a fixed width so the geometry assertions below
/// describe real laid-out pixels.
Future<void> _pumpBubble(WidgetTester tester, {required bool isUser}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: MessageBubble(
            message: ChatMessage(
              text: isUser ? 'Hi' : 'Hello there',
              isUser: isUser,
              createdAt: DateTime(2026, 8, 14, 10, 30),
            ),
            userGender: Gender.male,
            userName: 'Test User',
            showTimestamp: true,
            showName: true,
            showActions: true,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final bubbleFinder = find.byKey(const Key('messageBubbleBody'));
  final avatarFinder = find.byType(CircleAvatar);
  final shareFinder = find.byIcon(Icons.share_rounded);

  testWidgets('AIDA: avatar tops the bubble, share centers on the right', (
    tester,
  ) async {
    await _pumpBubble(tester, isUser: false);

    final bubble = tester.getRect(bubbleFinder);
    final avatar = tester.getRect(avatarFinder);
    final share = tester.getRect(shareFinder);

    // Avatar sits on the left, flush with the top of the bubble.
    expect(avatar.top, bubble.top);
    expect(avatar.right, lessThanOrEqualTo(bubble.left));

    // Share sits on the right, vertically centered against the bubble.
    expect(share.center.dy, closeTo(bubble.center.dy, 0.5));
    expect(share.left, greaterThanOrEqualTo(bubble.right));
  });

  testWidgets('user: avatar tops the bubble, share centers on the left', (
    tester,
  ) async {
    await _pumpBubble(tester, isUser: true);

    final bubble = tester.getRect(bubbleFinder);
    final avatar = tester.getRect(avatarFinder);
    final share = tester.getRect(shareFinder);

    // Avatar sits on the right, flush with the top of the bubble.
    expect(avatar.top, bubble.top);
    expect(avatar.left, greaterThanOrEqualTo(bubble.right));

    // Share sits on the left, vertically centered against the bubble.
    expect(share.center.dy, closeTo(bubble.center.dy, 0.5));
    expect(share.right, lessThanOrEqualTo(bubble.left));
  });

  testWidgets('share button shares a column with the opposite avatar', (
    tester,
  ) async {
    await _pumpBubble(tester, isUser: false);
    final aidaAvatar = tester.getRect(avatarFinder);
    final aidaShare = tester.getRect(shareFinder);

    await _pumpBubble(tester, isUser: true);
    final userAvatar = tester.getRect(avatarFinder);
    final userShare = tester.getRect(shareFinder);

    // AIDA's share button occupies the same column as the user's avatar,
    // and the user's share button the same column as AIDA's avatar.
    expect(aidaShare.center.dx, closeTo(userAvatar.center.dx, 0.5));
    expect(userShare.center.dx, closeTo(aidaAvatar.center.dx, 0.5));
  });
}
