import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/entities.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fixnum/fixnum.dart' as fixnum;

import 'ai_client.dart';
import 'ai_entities.dart';
import 'error.dart';

class AppFlowyAIService implements AIRepository {
  @override
  Future<(String, CompletionStream)?> streamCompletion({
    String? objectId,
    required String text,
    PredefinedFormat? format,
    required CompletionTypePB completionType,
    required Future<void> Function() onStart,
    required Future<void> Function(String text) onProcess,
    required Future<void> Function() onEnd,
    required void Function(AIError error) onError,
  }) async {
    final stream = CompletionStream(onStart, onProcess, onEnd, onError);

    final payload = CompleteTextPB(
      text: text,
      completionType: completionType,
      streamPort: fixnum.Int64(stream.nativePort),
      objectId: objectId ?? '',
      ragIds: [
        if (objectId != null) objectId,
      ],
    );

    return AIEventCompleteText(payload).send().fold(
      (completeTextTask) => (completeTextTask.taskId, stream),
      (error) {
        Log.error(error);
        return null;
      },
    );
  }
}

class CompletionStream {
  CompletionStream(
    Future<void> Function() onStart,
    Future<void> Function(String text) onProcess,
    Future<void> Function() onEnd,
    void Function(AIError error) onError,
  ) {
    _port.handler = _controller.add;
    _subscription = _controller.stream.listen(
      (event) async {
        if (event == "AI_RESPONSE_LIMIT") {
          onError(
            AIError(
              message: LocaleKeys.sideBar_aiResponseLimit.tr(),
              code: AIErrorCode.aiResponseLimitExceeded,
            ),
          );
        }

        if (event == "AI_IMAGE_RESPONSE_LIMIT") {
          onError(
            AIError(
              message: LocaleKeys.sideBar_aiImageResponseLimit.tr(),
              code: AIErrorCode.aiImageResponseLimitExceeded,
            ),
          );
        }

        if (event.startsWith("start:")) {
          await onStart();
        }

        if (event.startsWith("data:")) {
          await onProcess(event.substring(5));
        }

        if (event.startsWith("finish:")) {
          await onEnd();
        }

        if (event.startsWith("error:")) {
          onError(
            AIError(message: event.substring(6), code: AIErrorCode.other),
          );
        }
      },
    );
  }

  final RawReceivePort _port = RawReceivePort();
  final StreamController<String> _controller = StreamController.broadcast();
  late StreamSubscription<String> _subscription;
  int get nativePort => _port.sendPort.nativePort;

  Future<void> dispose() async {
    await _controller.close();
    await _subscription.cancel();
    _port.close();
  }

  StreamSubscription<String> listen(
    void Function(String event)? onData,
  ) {
    return _controller.stream.listen(onData);
  }
}
