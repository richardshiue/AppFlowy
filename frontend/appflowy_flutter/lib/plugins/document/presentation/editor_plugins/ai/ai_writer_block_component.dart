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
import 'operations/ai_writer_node_extension.dart';
import 'widgets/suggestion_action_bar.dart';

class AiWriterBlockKeys {
  const AiWriterBlockKeys._();

  static const String type = 'ai_writer';

  static const String isInitialized = 'is_initialized';
  static const String selection = 'selection';
  static const String command = 'command';

  /// Sample usage:
  ///
  /// `attributes: {
  ///   'ai_writer_delta_suggestion': 'original'
  /// }`
  static const String suggestion = 'ai_writer_delta_suggestion';
  static const String suggestionOriginal = 'original';
  static const String suggestionReplacement = 'replacement';
}

Node aiWriterNode({
  required Selection? selection,
  required AiWriterCommand command,
}) {
  return Node(
    type: AiWriterBlockKeys.type,
    attributes: {
      AiWriterBlockKeys.isInitialized: false,
      AiWriterBlockKeys.selection: selection?.toJson(),
      AiWriterBlockKeys.command: command.index,
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
      node.attributes[AiWriterBlockKeys.isInitialized] is bool &&
      node.attributes[AiWriterBlockKeys.selection] is Map? &&
      node.attributes[AiWriterBlockKeys.command] is int;
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
  final textController = TextEditingController();
  final textFieldFocusNode = FocusNode();
  final overlayController = OverlayPortalController();
  final layerLink = LayerLink();
  final selectedSourcesNotifier = ValueNotifier<List<String>>(const []);

  late final editorState = context.read<EditorState>();
  late final aiWriterCubit = AiWriterCubit(
    documentId: context.read<DocumentBloc>().documentId,
    editorState: editorState,
    getAiWriterNode: () => widget.node,
    initialCommand: widget.node.aiWriterCommand,
  );

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      overlayController.show();
      textFieldFocusNode.requestFocus();
      if (!widget.node.isAiWriterInitialized) {
        aiWriterCubit.init();
      }
    });
  }

  @override
  void dispose() {
    textController.dispose();
    textFieldFocusNode.dispose();
    selectedSourcesNotifier.dispose();
    aiWriterCubit.close();
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
                      onPointerDown: (_) => onTapOutside(),
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
                      child: OverlayContent(
                        node: widget.node,
                        selectedSourcesNotifier: selectedSourcesNotifier,
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

  void onTapOutside() {
    if (aiWriterCubit.hasUnusedResponse()) {
      showConfirmDialog(
        context: context,
        title: LocaleKeys.button_discard.tr(),
        description: LocaleKeys.document_plugins_discardResponse.tr(),
        confirmLabel: LocaleKeys.button_discard.tr(),
        style: ConfirmPopupStyle.cancelAndOk,
        onConfirm: () =>
            aiWriterCubit.runResponseAction(SuggestionAction.discard),
        onCancel: () {},
      );
    } else {
      aiWriterCubit.runResponseAction(SuggestionAction.discard);
    }
  }
}

class OverlayContent extends StatelessWidget {
  const OverlayContent({
    super.key,
    required this.node,
    required this.selectedSourcesNotifier,
  });

  final Node node;
  final ValueNotifier<List<String>> selectedSourcesNotifier;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiWriterCubit, AiWriterState>(
      builder: (context, state) {
        final selection = node.aiWriterSelection;
        final showSupplementaryPopups =
            state is ReadyAiWriterState && !state.isInitial;

        final bool showHeader;
        if (state is ReadyAiWriterState && state.markdownText.isNotEmpty ||
            state is GeneratingAiWriterState && state.markdownText.isNotEmpty) {
          showHeader = true;
        } else {
          showHeader = false;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSupplementaryPopups) ...[
              Container(
                padding: EdgeInsets.all(4.0),
                decoration: _getModalDecoration(
                  context,
                  borderRadius: BorderRadius.all(Radius.circular(8.0)),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: SuggestionActionBar(
                  actions: _getSuggestedActions(
                    currentCommand: node.aiWriterCommand,
                    hasSelection: selection != null && !selection.isCollapsed,
                  ),
                ),
              ),
              const VSpace(4.0 + 1.0),
            ],
            DecoratedBox(
              decoration: _getModalDecoration(
                context,
                borderRadius: BorderRadius.all(Radius.circular(12.0)),
              ),
              child: Column(
                children: [
                  if (showHeader) ...[
                    DecoratedBox(
                      decoration: _getHelperChildDecoration(context),
                      child: SizedBox(
                        height: 140,
                        width: double.infinity,
                      ),
                    ),
                    Divider(
                      height: 1.0,
                    ),
                  ],
                  DecoratedBox(
                    decoration: showHeader
                        ? _getInputChildDecoration(context)
                        : _getSingleChildDeocoration(context),
                    child: DesktopPromptInput(
                      isStreaming: false,
                      hideDecoration: true,
                      onStopStreaming: () {},
                      selectedSourcesNotifier: selectedSourcesNotifier,
                      onUpdateSelectedSources: (sources) {},
                      onSubmitted: (message, format, metadata) {},
                    ),
                  ),
                ],
              ),
            ),
            if (showSupplementaryPopups) ...[
              const VSpace(4.0 + 1.0),
              Container(
                padding: EdgeInsets.all(4.0),
                decoration: _getModalDecoration(
                  context,
                  borderRadius: BorderRadius.all(Radius.circular(8.0)),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: IntrinsicWidth(
                  child: SeparatedColumn(
                    separatorBuilder: () => const VSpace(4.0),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 30.0,
                        child: FlowyButton(
                          // leftIcon: FlowySvg(
                          //   command.icon,
                          //   size: const Size.square(16),
                          // ),
                          text: FlowyText(
                            AiWriterCommand.continueWriting.i18n,
                          ),
                          onTap: () {},
                        ),
                      ),
                      SizedBox(
                        height: 30.0,
                        child: FlowyButton(
                          // leftIcon: FlowySvg(
                          //   command.icon,
                          //   size: const Size.square(16),
                          // ),
                          text: FlowyText(
                            AiWriterCommand.fixSpellingAndGrammar.i18n,
                          ),
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  BoxDecoration _getModalDecoration(
    BuildContext context, {
    required BorderRadius borderRadius,
    Color? color,
  }) {
    return BoxDecoration(
      color: color,
      border: Border.all(
        color: Theme.of(context).colorScheme.outline,
        strokeAlign: BorderSide.strokeAlignOutside,
      ),
      borderRadius: borderRadius,
      boxShadow: const [
        BoxShadow(
          offset: Offset(0, 4),
          blurRadius: 20,
          color: Color(0x1A1F2329),
        ),
      ],
    );
  }

  BoxDecoration _getSingleChildDeocoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.all(Radius.circular(12.0)),
    );
  }

  BoxDecoration _getHelperChildDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
    );
  }

  BoxDecoration _getInputChildDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(12.0)),
    );
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
        AiWriterCommand.explain => [
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
        AiWriterCommand.explain => [
            SuggestionAction.insertBelow,
            SuggestionAction.tryAgain,
            SuggestionAction.close,
          ],
        _ => throw UnimplementedError(),
      };
    }
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
