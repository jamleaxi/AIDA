import 'package:aida/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('createdAt, isError, and status default to null/false/null', () {
    final message = ChatMessage(text: 'hi', isUser: true);

    expect(message.text, 'hi');
    expect(message.isUser, isTrue);
    expect(message.createdAt, isNull);
    expect(message.isError, isFalse);
    expect(message.status, isNull);
  });

  test('stores every field it is constructed with', () {
    final now = DateTime(2026, 1, 1);
    final message = ChatMessage(
      text: 'oops',
      isUser: false,
      createdAt: now,
      isError: true,
      status: MessageStatus.failed,
    );

    expect(message.text, 'oops');
    expect(message.isUser, isFalse);
    expect(message.createdAt, now);
    expect(message.isError, isTrue);
    expect(message.status, MessageStatus.failed);
  });

  test('status is mutable in place, so the same instance reflects updates', () {
    final message = ChatMessage(
      text: 'hi',
      isUser: true,
      status: MessageStatus.sending,
    );

    message.status = MessageStatus.sent;

    expect(message.status, MessageStatus.sent);
  });
}
