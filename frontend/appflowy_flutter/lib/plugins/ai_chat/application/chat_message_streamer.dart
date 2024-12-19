import 'package:appflowy/util/int64_extension.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/protobuf.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'chat_entity.dart';
import 'chat_message_stream.dart';

enum SendChatMessageState {
  idle,
  streamingQuestion,
  waitingAnswerStream,
  streamingAnswer,
  complete,
}

abstract class ChatMessageStreamer {
  Message? processNewMessage(ChatMessagePB messagePB);
  void dispose();
}

class UserExchangeStreamer implements ChatMessageStreamer {
  UserExchangeStreamer({
    required this.fakeQuestionId,
    required this.fakeAnswerId,
    required this.questionId,
    required this.answerId,
  });

  final String fakeQuestionId;
  final String fakeAnswerId;
  final String questionId;
  final String answerId;

  QuestionStream? questionStream;
  AnswerStream? answerStream;

  void startSending() {}

  @override
  Message? processNewMessage(ChatMessagePB messagePB) {
    final String messageId = switch (messagePB.authorType.toInt()) {
      1 when fakeQuestionId.isNotEmpty => fakeQuestionId,
      3 when fakeAnswerId.isNotEmpty => fakeAnswerId,
      _ => messagePB.messageId.toString(),
    };

    return TextMessage(
      author: User(id: messagePB.authorId),
      id: messageId,
      text: messagePB.content,
      createdAt: messagePB.createdAt.toDateTime(),
      metadata: {messageRefSourceJsonStringKey: messagePB.metadata},
    );
  }

  @override
  void dispose() {
    questionStream?.dispose();
    answerStream?.dispose();
  }
}

class RegenerateStreamer implements ChatMessageStreamer {
  AnswerStream? answerStream;

  @override
  Message? processNewMessage(ChatMessagePB messagePB) => null;

  @override
  void dispose() => answerStream?.dispose();
}
