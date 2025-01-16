import 'dart:async';

import 'package:appflowy/ai/ai.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/protobuf.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:bloc/bloc.dart';

import '../../base/markdown_text_robot.dart';
import 'ai_writer_block_operations.dart';
import 'ai_writer_entities.dart';
import 'ai_writer_node_extension.dart';

class AiWriterCubit extends Cubit<AiWriterState> {
  AiWriterCubit({
    required this.documentId,
    required this.editorState,
    required this.getAiWriterNode,
    this.initialCommand = AiWriterCommand.userQuestion,
    AppFlowyAIService? aiService,
  })  : _aiService = aiService ?? AppFlowyAIService(),
        _textRobot = MarkdownTextRobot(editorState: editorState),
        super(ReadyAiWriterState(isInitial: true, command: initialCommand));

  final String documentId;
  final EditorState editorState;
  final Node Function() getAiWriterNode;
  final AiWriterCommand initialCommand;
  final AppFlowyAIService _aiService;
  final MarkdownTextRobot _textRobot;

  (String, PredefinedFormat?)? _previousPrompt;

  void init() => _runCommand(false);

  void submit(String prompt, PredefinedFormat? format) async {
    emit(const StartGeneratingAiWriterState());

    _previousPrompt = (prompt, format);
    final node = getAiWriterNode();

    final stream = await _aiService.streamCompletion(
      objectId: documentId,
      text: prompt,
      format: format,
      completionType: AiWriterCommand.userQuestion.toCompletionType(),
      onStart: () async {
        final transaction = editorState.transaction;
        ensurePreviousNodeIsEmptyParagraph(editorState, node, transaction);
        await editorState.apply(
          transaction,
          options: ApplyOptions(inMemoryUpdate: true),
        );
        _textRobot.start();
      },
      onProcess: (text) async {
        await _textRobot.appendMarkdownText(text);
      },
      onEnd: () async {
        editorState.service.keyboardService?.enable();
        emit(const StopGeneratingAiWriterState());
        emit(
          ReadyAiWriterState(
            isInitial: false,
            command: AiWriterCommand.userQuestion,
          ),
        );
      },
      onError: (error) async {
        emit(const StopGeneratingAiWriterState());
        emit(ErrorAiWriterState(error: error));
      },
    );

    if (stream != null) {
      emit(
        GeneratingAiWriterState(
          taskId: stream.$1,
          command: AiWriterCommand.userQuestion,
        ),
      );
    }
  }

  void stop() async {
    if (state is! GeneratingAiWriterState) {
      return;
    }

    await AIEventStopCompleteText(
      CompleteTextTaskPB(
        taskId: (state as GeneratingAiWriterState).taskId,
      ),
    ).send();

    final stateCopy = state;
    emit(const StopGeneratingAiWriterState());
    emit(stateCopy);
  }

  void runResponseAction(SuggestionAction action) async {
    switch (action) {
      case SuggestionAction.accept:
      case SuggestionAction.keep:
        await _textRobot.persist();
        final selection = getAiWriterNode().aiWriterSelection;
        if (selection != null) {
          final nodes = editorState.getNodesInSelection(selection);
          final transaction = editorState.transaction..deleteNodes(nodes);
          await editorState.apply(
            transaction,
            options: const ApplyOptions(
              inMemoryUpdate: true,
              recordUndo: false,
            ),
            withUpdateSelection: false,
          );
        }
        await removeAiWriterNode(editorState, getAiWriterNode());
        break;
      case SuggestionAction.insertBelow:
        await _textRobot.persist();
        await removeAiWriterNode(editorState, getAiWriterNode());
        break;
      case SuggestionAction.discard:
      case SuggestionAction.close:
        await _textRobot.discard();
        await removeAiWriterNode(editorState, getAiWriterNode());
        break;
      case SuggestionAction.rewrite:
      case SuggestionAction.tryAgain:
        await _textRobot.discard();
        _textRobot.reset();
        _runCommand(true);
        break;
    }
  }

  bool hasUnusedResponse() {
    return switch (state) {
      ReadyAiWriterState(
        isInitial: final isInitial,
        markdownText: final markdownText,
      ) =>
        !isInitial && (markdownText.isNotEmpty || _textRobot.hasAnyResult),
      GeneratingAiWriterState() => true,
      _ => false,
    };
  }

  void _runCommand(bool isRetry) async {
    switch (initialCommand) {
      case AiWriterCommand.continueWriting:
        await _startContinueWriting(command: initialCommand);
        break;
      case AiWriterCommand.fixSpellingAndGrammar:
      case AiWriterCommand.improveWriting:
      case AiWriterCommand.makeLonger:
      case AiWriterCommand.makeShorter:
        await _startSuggestingEdits(command: initialCommand);
        break;
      case AiWriterCommand.explain:
        await _startInforming(command: initialCommand);
        break;
      case AiWriterCommand.userQuestion:
        if (isRetry && _previousPrompt != null) {
          submit(_previousPrompt!.$1, _previousPrompt!.$2);
        }
        break;
    }
  }

  Future<void> _startContinueWriting({
    required AiWriterCommand command,
  }) async {
    final node = getAiWriterNode();
    emit(const StartGeneratingAiWriterState());
    final stream = await _aiService.streamCompletion(
      objectId: documentId,
      text: '',
      completionType: command.toCompletionType(),
      onStart: () async {
        final transaction = editorState.transaction;
        ensurePreviousNodeIsEmptyParagraph(editorState, node, transaction);
        await editorState.apply(
          transaction,
          options: ApplyOptions(inMemoryUpdate: true),
        );
        _textRobot.start();
      },
      onProcess: (text) async {
        await _textRobot.appendMarkdownText(text);
      },
      onEnd: () async {
        editorState.service.keyboardService?.enable();
        if (state case GeneratingAiWriterState _) {
          emit(const StopGeneratingAiWriterState());
          emit(ReadyAiWriterState(isInitial: false, command: command));
        }
      },
      onError: (error) async {
        editorState.service.keyboardService?.enable();
        emit(const StopGeneratingAiWriterState());
        emit(ErrorAiWriterState(error: error));
      },
    );
    if (stream != null) {
      emit(
        GeneratingAiWriterState(
          taskId: stream.$1,
          command: command,
        ),
      );
    }
  }

  Future<void> _startSuggestingEdits({
    required AiWriterCommand command,
  }) async {
    final node = getAiWriterNode();
    final selection = node.aiWriterSelection;
    if (selection == null) {
      return;
    }
    emit(const StartGeneratingAiWriterState());

    final stream = await _aiService.streamCompletion(
      objectId: documentId,
      text: await editorState.getMarkdownInSelection(selection),
      completionType: command.toCompletionType(),
      onStart: () async {
        final transaction = editorState.transaction;
        formatSelection(
          editorState,
          selection,
          transaction,
          ApplySuggestionFormatType.original,
        );
        ensurePreviousNodeIsEmptyParagraph(editorState, node, transaction);
        await editorState.apply(
          transaction,
          options: ApplyOptions(
            inMemoryUpdate: true,
            recordUndo: false,
          ),
        );
        _textRobot.start();
      },
      onProcess: (text) async {
        await _textRobot.appendMarkdownText(
          text,
          attributes: ApplySuggestionFormatType.replace.attributes,
        );
      },
      onEnd: () async {
        final stateCopy = state;
        emit(const StopGeneratingAiWriterState());
        emit(stateCopy);
      },
      onError: (error) async {
        editorState.service.keyboardService?.enable();
        emit(const StopGeneratingAiWriterState());
        emit(ErrorAiWriterState(error: error));
      },
    );
    if (stream != null) {
      emit(
        GeneratingAiWriterState(
          taskId: stream.$1,
          command: command,
        ),
      );
    }
  }

  Future<void> _startInforming({
    required AiWriterCommand command,
  }) async {
    final node = getAiWriterNode();
    final selection = node.aiWriterSelection;
    if (selection == null) {
      return;
    }
    emit(const StartGeneratingAiWriterState());

    final stream = await _aiService.streamCompletion(
      objectId: documentId,
      text: await editorState.getMarkdownInSelection(selection),
      completionType: command.toCompletionType(),
      onStart: () async {},
      onProcess: (text) async {
        if (state case final GeneratingAiWriterState generatingState) {
          emit(
            GeneratingAiWriterState(
              taskId: generatingState.taskId,
              command: generatingState.command,
              markdownText: generatingState.markdownText + text,
            ),
          );
        }
      },
      onEnd: () async {
        editorState.service.keyboardService?.enable();
        final stateCopy = state;
        emit(const StopGeneratingAiWriterState());
        emit(stateCopy);
      },
      onError: (error) async {
        emit(const StopGeneratingAiWriterState());
        emit(ErrorAiWriterState(error: error));
      },
    );
    if (stream != null) {
      emit(
        GeneratingAiWriterState(
          taskId: stream.$1,
          command: command,
        ),
      );
    }
  }
}

sealed class AiWriterState {
  const AiWriterState();
}

class ReadyAiWriterState implements AiWriterState {
  const ReadyAiWriterState({
    required this.isInitial,
    required this.command,
    this.markdownText = '',
  });

  final bool isInitial;
  final AiWriterCommand command;
  final String markdownText;
}

class GeneratingAiWriterState implements AiWriterState {
  const GeneratingAiWriterState({
    required this.taskId,
    required this.command,
    this.progress = '',
    this.markdownText = '',
  });

  final String taskId;
  final AiWriterCommand command;
  final String progress;
  final String markdownText;
}

class LimitReachedAIWriterState implements AiWriterState {
  const LimitReachedAIWriterState();
}

class ErrorAiWriterState implements AiWriterState {
  const ErrorAiWriterState({
    required this.error,
  });

  final AIError error;
}

class StartGeneratingAiWriterState implements AiWriterState {
  const StartGeneratingAiWriterState();
}

class StopGeneratingAiWriterState implements AiWriterState {
  const StopGeneratingAiWriterState();
}
