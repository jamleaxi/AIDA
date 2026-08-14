import 'package:aida/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('createdAt and isError default to null and false', () {
    const message = ChatMessage(text: 'hi', isUser: true);

    expect(message.text, 'hi');
    expect(message.isUser, isTrue);
    expect(message.createdAt, isNull);
    expect(message.isError, isFalse);
  });

  test('stores every field it is constructed with', () {
    final now = DateTime(2026, 1, 1);
    final message = ChatMessage(
      text: 'oops',
      isUser: false,
      createdAt: now,
      isError: true,
    );

    expect(message.text, 'oops');
    expect(message.isUser, isFalse);
    expect(message.createdAt, now);
    expect(message.isError, isTrue);
  });
}
