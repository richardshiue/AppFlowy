import 'dart:async';

import 'package:appflowy/ai/ai.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/protobuf.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:bloc/bloc.dart';

import '../../base/markdown_text_robot.dart';
import 'ai_writer_block_operations.dart';
import 'ai_writer_entities.dart';
import 'ask_ai_node_extension.dart';

class AiWriterCubit extends Cubit<AiWriterState> {
  AiWriterCubit({
    required this.documentId,
    required this.editorState,
    required this.node,
    this.initialCommand = AiWriterCommand.userQuestion,
  })  : _aiService = AppFlowyAIService(),
        _textRobot = MarkdownTextRobot(editorState: editorState),
        super(const ReadyAiWriterState());

  final String documentId;
  final EditorState editorState;
  final Node node;
  final AiWriterCommand initialCommand;
  final AppFlowyAIService _aiService;
  final MarkdownTextRobot _textRobot;

  Selection? selection;

  void init() async {
    if (initialCommand == AiWriterCommand.userQuestion) {
      return;
    }

    selection = editorState.selection;

    emit(const StartGeneratingAiWriterState());

    switch (initialCommand) {
      case AiWriterCommand.continueWriting:
        await _startContinueWriting(
          completionType: initialCommand.toCompletionType(),
        );
        break;
      case AiWriterCommand.fixSpellingAndGrammar:
      case AiWriterCommand.improveWriting:
      case AiWriterCommand.makeLonger:
      case AiWriterCommand.makeShorter:
        await _startSuggestingEdits(
          completionType: initialCommand.toCompletionType(),
        );
        break;
      case AiWriterCommand.explain:
      case AiWriterCommand.summarize:
        await _startInforming(
          completionType: initialCommand.toCompletionType(),
        );
        break;
      case AiWriterCommand.userQuestion:
        break;
    }
  }

  void submit(String prompt, PredefinedFormat? format) async {
    if (state is! ReadyAiWriterState) {
      return;
    }

    // TODO: on second question asked

    final stateCopy = state;
    emit(const StartGeneratingAiWriterState());

    // await editorState.updatePromptText(node, prompt);

    final stream = await _aiService.streamCompletion(
      objectId: documentId,
      text: prompt,
      completionType: AiWriterCommand.userQuestion.toCompletionType(),
      onStart: () async {
        await editorState.ensurePreviousNodeIsEmptyParagraphNode(node);
        _textRobot.start(
          editSelectionStyle: TextRobotEditSelectionStyle.append,
        );
      },
      onProcess: (text) async {
        await _textRobot.appendMarkdownText(text);
      },
      onEnd: () async {
        await _textRobot.stop();
        editorState.service.keyboardService?.enable();
        emit(const StopGeneratingAiWriterState());
        emit(stateCopy);
        // await editorState.updateGenerationCount(generationCount + 1);
      },
      onError: (error) async {
        await _textRobot.stop();
        emit(const StopGeneratingAiWriterState());
        emit(const ErrorAiWriterState());
      },
    );

    if (stream != null) {
      emit(GeneratingAiWriterState(taskId: stream.$1));
    } else {
      emit(const ErrorAiWriterState());
    }
  }

  void stop() {
    if (state is! GeneratingAiWriterState) {
      return;
    }

    AIEventStopCompleteText(
      CompleteTextTaskPB(
        taskId: (state as GeneratingAiWriterState).taskId,
      ),
    ).send();

    // emit?
  }

  void retry() {}

  void runResponseAction(SuggestionAction action) {
    if (state is! ReadyAiWriterState) {
      return;
    }

    // insert below should only
    switch (action) {
      case SuggestionAction.accept:
        // TODO: handle fix spelling and grammar and improve writing
        // editorState.replace(
        //   node: node,
        //   markdownText: markdownText,
        // );
        editorState.removeAiWriterNode(node);
        break;
      case SuggestionAction.discard:
        _textRobot.discard();
        editorState.removeAiWriterNode(node);
        break;
      case SuggestionAction.rewrite:
        _textRobot.discard();
        break;
      case SuggestionAction.tryAgain:
        _textRobot.discard();
        break;
      case SuggestionAction.close:
        _textRobot.discard();
        editorState.removeAiWriterNode(node);
        break;
      default:
        break;
    }
  }

  void discard() {
    // TODO
    editorState.discardCurrentResponse(aiWriterNode: node);
    editorState.removeAiWriterNode(node);
  }

  bool hasUnusedResponse() {
    // TODO
    return true;
  }

  Future<void> _startContinueWriting({
    required CompletionTypePB completionType,
  }) async {
    if (selection == null) {
      return;
    }

    await editorState.ensureSelectionIsInParagraph(node, selection!);

    return;

    // ignore: dead_code
    final stream = await _aiService.streamCompletion(
      objectId: documentId,
      text: '',
      completionType: completionType,
      onStart: () async {
        await editorState.ensurePreviousNodeIsEmptyParagraphNode(node);
        // TODO: or editorState.selection = null
        await editorState.updateSelectionWithReason(null);
        _textRobot.start(
          editSelectionStyle: TextRobotEditSelectionStyle.append,
        );
      },
      onProcess: (text) async {
        await _textRobot.appendMarkdownText(text);
      },
      onEnd: () async {
        await _textRobot.stop();
        editorState.service.keyboardService?.enable();
        final stateCopy = state;
        emit(const StopGeneratingAiWriterState());
        emit(stateCopy);
        // await editorState.updateGenerationCount(generationCount + 1);
      },
      onError: (error) async {
        await _textRobot.stop();
        editorState.service.keyboardService?.enable();
        emit(const StopGeneratingAiWriterState());
        emit(const ErrorAiWriterState());
      },
    );
    if (stream != null) {
      emit(GeneratingAiWriterState(taskId: stream.$1));
    } else {
      emit(const ErrorAiWriterState());
    }
  }

  Future<void> _startSuggestingEdits({
    required CompletionTypePB completionType,
  }) async {
    final stream = await _aiService.streamCompletion(
      objectId: documentId,
      text: '',
      completionType: completionType,
      onStart: () async {
        await editorState.ensurePreviousNodeIsEmptyParagraphNode(node);
        // TODO: or editorState.selection = null
        await editorState.updateSelectionWithReason(null);
        _textRobot.start(
          editSelectionStyle: TextRobotEditSelectionStyle.crossOutAndAppend,
        );
      },
      onProcess: (text) async {
        await _textRobot.appendMarkdownText(text);
      },
      onEnd: () async {
        await _textRobot.stop();
        editorState.service.keyboardService?.enable();
        final stateCopy = state;
        emit(const StopGeneratingAiWriterState());
        emit(stateCopy);
        // await editorState.updateGenerationCount(generationCount + 1);
      },
      onError: (error) async {
        await _textRobot.stop();
        editorState.service.keyboardService?.enable();
        emit(const StopGeneratingAiWriterState());
        emit(const ErrorAiWriterState());
      },
    );
    if (stream != null) {
      emit(GeneratingAiWriterState(taskId: stream.$1));
    } else {
      emit(const ErrorAiWriterState());
    }
  }

  Future<void> _startInforming({
    required CompletionTypePB completionType,
  }) async {
    final stream = await _aiService.streamCompletion(
      objectId: documentId,
      text: editorState.getMarkdownInSelection(selection),
      completionType: completionType,
      onStart: () async {},
      onProcess: (text) async {
        final String markdownText;
        if (state case final ReadyAiWriterState readyState) {
          markdownText = readyState.markdownText + text;
        } else {
          markdownText = text;
        }
        emit(ReadyAiWriterState(markdownText: markdownText));
      },
      onEnd: () async {
        editorState.service.keyboardService?.enable();
        final stateCopy = state;
        emit(const StopGeneratingAiWriterState());
        emit(stateCopy);
      },
      onError: (error) async {
        emit(const StopGeneratingAiWriterState());
        emit(const ErrorAiWriterState());
      },
    );
    if (stream != null) {
      emit(GeneratingAiWriterState(taskId: stream.$1));
    } else {
      emit(const ErrorAiWriterState());
    }
  }
}

sealed class AiWriterState {
  const AiWriterState();
}

class ReadyAiWriterState implements AiWriterState {
  const ReadyAiWriterState({
    this.isInitial = true,
    this.inProgress = false,
    this.command = AiWriterCommand.userQuestion,
    this.markdownText = '',
    this.actions = const [],
  });

  final bool isInitial;
  final bool inProgress;
  final AiWriterCommand command;
  final String markdownText;
  final List<SuggestionAction> actions;
}

class GeneratingAiWriterState implements AiWriterState {
  const GeneratingAiWriterState({
    required this.taskId,
  });

  final String taskId;
}

class LimitReachedAIWriterState implements AiWriterState {
  const LimitReachedAIWriterState();
}

class ErrorAiWriterState implements AiWriterState {
  const ErrorAiWriterState();
}

class StartGeneratingAiWriterState implements AiWriterState {
  const StartGeneratingAiWriterState();
}

class StopGeneratingAiWriterState implements AiWriterState {
  const StopGeneratingAiWriterState();
}
