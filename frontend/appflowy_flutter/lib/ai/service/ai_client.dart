import 'package:appflowy_backend/protobuf/flowy-ai/protobuf.dart';

import 'ai_entities.dart';
import 'error.dart';

abstract class AIRepository {
  Future<void> streamCompletion({
    String? objectId,
    required String text,
    PredefinedFormat? format,
    required CompletionTypePB completionType,
    required Future<void> Function() onStart,
    required Future<void> Function(String text) onProcess,
    required Future<void> Function() onEnd,
    required void Function(AIError error) onError,
  });
}
