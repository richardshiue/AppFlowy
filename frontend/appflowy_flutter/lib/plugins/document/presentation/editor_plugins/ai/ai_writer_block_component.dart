import 'package:appflowy/ai/ai.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/application/prelude.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/space/shared_widget.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';

import 'operations/ai_writer_cubit.dart';
import 'operations/ai_writer_entities.dart';
import 'widgets/suggestion_action_bar.dart';

class AIWriterBlockKeys {
  const AIWriterBlockKeys._();

  static const String type = 'ai_writer';

  static const String isInitialized = 'is_initialized';
  static const String selection = 'selection';
  static const String command = 'command';
}

Node aiWriterNode({
  required Selection? selection,
  required AiWriterCommand command,
}) {
  return Node(
    type: AIWriterBlockKeys.type,
    attributes: {
      AIWriterBlockKeys.isInitialized: false,
      AIWriterBlockKeys.selection: selection?.toJson(),
      AIWriterBlockKeys.command: command.index,
    },
  );
}

class AIWriterBlockComponentBuilder extends BlockComponentBuilder {
  AIWriterBlockComponentBuilder();

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return AIWriterBlockComponent(
      key: node.key,
      node: node,
      showActions: showActions(node),
      actionBuilder: (context, state) => actionBuilder(
        blockComponentContext,
        state,
      ),
    );
  }

  @override
  BlockComponentValidate get validate => (node) =>
      node.children.isEmpty &&
      node.attributes[AIWriterBlockKeys.isInitialized] is bool &&
      node.attributes[AIWriterBlockKeys.selection] is Map? &&
      node.attributes[AIWriterBlockKeys.command] is int;
}

class AIWriterBlockComponent extends BlockComponentStatefulWidget {
  const AIWriterBlockComponent({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<AIWriterBlockComponent> createState() => _AIWriterBlockComponentState();
}

class _AIWriterBlockComponentState extends State<AIWriterBlockComponent> {
  final key = GlobalKey();
  final controller = TextEditingController();
  final textFieldFocusNode = FocusNode();
  final overlayController = OverlayPortalController();
  final layerLink = LayerLink();
  final selectedSourcesNotifier = ValueNotifier<List<String>>(const []);

  late final editorState = context.read<EditorState>();
  late final SelectionGestureInterceptor interceptor;
  late final aiWriterCubit = AiWriterCubit(
    documentId: context.read<DocumentBloc>().documentId,
    editorState: editorState,
    node: widget.node,
    initialCommand: command,
  );

  bool get isInitialized {
    return widget.node.attributes[AIWriterBlockKeys.isInitialized];
  }

  Selection? get startSelection {
    final selection = widget.node.attributes[AIWriterBlockKeys.selection];
    if (selection == null) {
      return null;
    }
    return Selection.fromJson(selection);
  }

  AiWriterCommand get command {
    final index = widget.node.attributes[AIWriterBlockKeys.command];
    return AiWriterCommand.values[index];
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      overlayController.show();
      textFieldFocusNode.requestFocus();
      if (!isInitialized) {
        aiWriterCubit.init();
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    textFieldFocusNode.dispose();
    selectedSourcesNotifier.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (UniversalPlatform.isMobile) {
      return const SizedBox.shrink();
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(
          value: aiWriterCubit,
        ),
        BlocProvider(
          create: (context) => AIPromptInputBloc(),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          return OverlayPortal(
            controller: overlayController,
            overlayChildBuilder: (context) {
              return Stack(
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.basic,
                    hitTestBehavior: HitTestBehavior.opaque,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) {
                        if (aiWriterCubit.hasUnusedResponse()) {
                          showConfirmDialog(
                            context: context,
                            title: "Discard",
                            description: LocaleKeys
                                .document_plugins_discardResponse
                                .tr(),
                            confirmLabel: LocaleKeys.button_discard.tr(),
                            style: ConfirmPopupStyle.cancelAndOk,
                            onConfirm: () => aiWriterCubit.discard(),
                            onCancel: () {},
                          );
                        } else {
                          aiWriterCubit.discard();
                        }
                      },
                    ),
                  ),
                  CompositedTransformFollower(
                    link: layerLink,
                    child: Container(
                      padding: const EdgeInsets.only(
                        left: 40.0,
                        bottom: 16.0,
                      ),
                      width: constraints.maxWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SuggestionActionBar(
                            showDecoration: true,
                            children: [],
                          ),
                          const VSpace(4),
                          DesktopPromptInput(
                            isStreaming: false,
                            usePopoverDecorationStyle: true,
                            onStopStreaming: () {},
                            selectedSourcesNotifier: selectedSourcesNotifier,
                            onUpdateSelectedSources: (sources) {},
                            onSubmitted: (message, format, metadata) {},
                          ),
                          const VSpace(4),
                          // TODO: suggested actions
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            child: CompositedTransformTarget(
              link: layerLink,
              child: BlocBuilder<AiWriterCubit, AiWriterState>(
                builder: (context, state) {
                  return SizedBox(
                    key: key,
                    width: double.infinity,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  bool get _isAIWriterEnabled {
    final userProfile = context.read<DocumentBloc>().state.userProfilePB;
    final isAIWriterEnabled = userProfile != null;

    if (!isAIWriterEnabled) {
      showToastNotification(
        context,
        message: LocaleKeys.document_plugins_autoGeneratorCantGetOpenAIKey.tr(),
        type: ToastificationType.error,
      );
    }

    return isAIWriterEnabled;
  }
}

List<SuggestionAction> _getSuggestedActions({
  required AiWriterCommand currentCommand,
  required bool hasSelection,
}) {
  if (hasSelection) {
    return switch (currentCommand) {
      AiWriterCommand.userQuestion || AiWriterCommand.continueWriting => [
          SuggestionAction.keep,
          SuggestionAction.discard,
          SuggestionAction.rewrite,
        ],
      AiWriterCommand.explain || AiWriterCommand.summarize => [
          SuggestionAction.insertBelow,
          SuggestionAction.tryAgain,
          SuggestionAction.close,
        ],
      AiWriterCommand.fixSpellingAndGrammar ||
      AiWriterCommand.improveWriting =>
        [
          SuggestionAction.accept,
          SuggestionAction.discard,
          SuggestionAction.insertBelow,
          SuggestionAction.rewrite,
        ],
      AiWriterCommand.makeShorter || AiWriterCommand.makeLonger => [
          SuggestionAction.keep,
          SuggestionAction.discard,
          SuggestionAction.rewrite,
        ]
    };
  } else {
    return switch (currentCommand) {
      AiWriterCommand.userQuestion || AiWriterCommand.continueWriting => [
          SuggestionAction.keep,
          SuggestionAction.discard,
          SuggestionAction.rewrite,
        ],
      AiWriterCommand.explain || AiWriterCommand.summarize => [
          SuggestionAction.insertBelow,
          SuggestionAction.tryAgain,
          SuggestionAction.close,
        ],
      // TODO: fix spelling and grammar, improve writing
      _ => throw UnimplementedError(),
    };
  }
}


// LocaleKeys.document_plugins_autoGeneratorRewrite.tr()
// LocaleKeys.button_insertBelow.tr()
// LocaleKeys.button_replace.tr()
// LocaleKeys.button_cancel.tr()
// LocaleKeys.document_plugins_warning.tr()
// LocaleKeys.button_generate.tr()
// LocaleKeys.button_cancel.tr()
// LocaleKeys.document_plugins_warning.tr()
// LocaleKeys.document_plugins_autoGeneratorRewrite.tr()
// LocaleKeys.button_keep.tr()
// LocaleKeys.button_discard.tr()
