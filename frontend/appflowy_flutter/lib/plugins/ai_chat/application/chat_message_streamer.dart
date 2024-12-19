import 'package:appflowy/util/int64_extension.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/protobuf.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:nanoid/nanoid.dart';

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
  void start();
  bool isComplete(ChatMessagePB messagePB);
  Message? processNewMessage(ChatMessagePB messagePB);
  void dispose();
}

class UserExchangeStreamer implements ChatMessageStreamer {
  UserExchangeStreamer({
    required this.message,
    this.metadata,
  });

  final String message;
  final Map<String, dynamic>? metadata;

  String fakeQuestionId = '';
  String fakeAnswerId = '';
  String questionId = '';
  String answerId = '';

  QuestionStream? questionStream;
  AnswerStream? answerStream;

  @override
  void start() async {
    questionStream = QuestionStream();
    answerStream = AnswerStream();
    fakeQuestionId = nanoid();
    fakeAnswerId = nanoid();

    final payload = StreamChatPayloadPB(
      chatId: chatId,
      message: message,
      messageType: ChatMessageTypePB.User,
      questionStreamPort: Int64(questionStream.nativePort),
      answerStreamPort: Int64(answerStream!.nativePort),
      metadata: await metadataPBFromMetadata(metadata),
    );

    // stream the question to the server
    await AIEventStreamMessage(payload).send().fold(
      (question) {
        if (!isClosed) {
          final streamAnswer = _createAnswerStreamMessage(
            answerStream!,
            question.messageId,
          );

          add(ChatEvent.finishSending(question));
          add(ChatEvent.receiveMessage(streamAnswer));
          add(ChatEvent.startAnswerStreaming(streamAnswer));
        }
      },
      (err) {
        if (!isClosed) {
          Log.error("Failed to send message: ${err.msg}");

          final metadata = {
            onetimeShotType: OnetimeShotType.error,
            if (err.code != ErrorCode.Internal) errorMessageTextKey: err.msg,
          };

          final error = TextMessage(
            text: '',
            metadata: metadata,
            author: const User(id: systemUserId),
            id: systemUserId,
            createdAt: DateTime.now(),
          );

          add(const ChatEvent.failedSending());
          add(ChatEvent.receiveMessage(error));
        }
      },
    );
  }

  @override
  bool isComplete(ChatMessagePB messagePB) {
    return messagePB.messageId.toString() == answerId;
  }

  @override
  Message? processNewMessage(ChatMessagePB messagePB) {
    late final String messageId;

    switch (messagePB.authorType.toInt()) {
      case 1 when fakeQuestionId.isNotEmpty:
        messageId = fakeQuestionId;
        questionId = messagePB.messageId.toString();
        break;
      case 3 when fakeAnswerId.isNotEmpty:
        messageId = fakeAnswerId;
        answerId = messagePB.messageId.toString();
        break;
      default:
        messageId = messagePB.messageId.toString();
        break;
    }

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
  Message? processNewMessage(ChatMessagePB messagePB) {
    return TextMessage(
      author: User(id: messagePB.authorId),
      id: messagePB.messageId.toString(),
      text: messagePB.content,
      createdAt: messagePB.createdAt.toDateTime(),
      metadata: {messageRefSourceJsonStringKey: messagePB.metadata},
    );
  }

  @override
  void dispose() => answerStream?.dispose();

  @override
  bool isComplete(ChatMessagePB messagePB) {
    // TODO: implement isComplete
    throw UnimplementedError();
  }
}
