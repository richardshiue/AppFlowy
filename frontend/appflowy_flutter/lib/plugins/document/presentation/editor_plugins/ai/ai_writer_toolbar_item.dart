import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/application/document_bloc.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'ai_writer_block_component.dart';
import 'operations/ai_writer_entities.dart';

const _kAskAIToolbarItemId = 'appflowy.editor.ask_ai';

final ToolbarItem askAIItem = ToolbarItem(
  id: _kAskAIToolbarItemId,
  group: 0,
  isActive: onlyShowInSingleSelectionAndTextType,
  builder: (context, editorState, _, __, tooltipBuilder) =>
      AskAiToolbarActionList(
    editorState: editorState,
    tooltipBuilder: tooltipBuilder,
  ),
);

class AskAiToolbarActionList extends StatefulWidget {
  const AskAiToolbarActionList({
    super.key,
    required this.editorState,
    this.tooltipBuilder,
  });

  final EditorState editorState;
  final ToolbarTooltipBuilder? tooltipBuilder;

  @override
  State<AskAiToolbarActionList> createState() => _AskAiToolbarActionListState();
}

class _AskAiToolbarActionListState extends State<AskAiToolbarActionList> {
  final popoverController = PopoverController();

  @override
  Widget build(BuildContext context) {
    return AppFlowyPopover(
      controller: popoverController,
      direction: PopoverDirection.bottomWithLeftAligned,
      offset: const Offset(-8.0, 2.0),
      margin: const EdgeInsets.all(8.0),
      onOpen: () => keepEditorFocusNotifier.increase(),
      onClose: () => keepEditorFocusNotifier.decrease(),
      popupBuilder: (context) => buildPopoverContent(),
      child: buildChild(),
    );
  }

  Widget buildPopoverContent() {
    return SeparatedColumn(
      mainAxisSize: MainAxisSize.min,
      separatorBuilder: () => const VSpace(4.0),
      children: [
        actionWrapper(AiWriterCommand.improveWriting),
        actionWrapper(AiWriterCommand.userQuestion),
        actionWrapper(AiWriterCommand.fixSpellingAndGrammar),
        actionWrapper(AiWriterCommand.summarize),
        actionWrapper(AiWriterCommand.explain),
        divider(),
        actionWrapper(AiWriterCommand.makeLonger),
        actionWrapper(AiWriterCommand.makeShorter),
      ],
    );
  }

  Widget actionWrapper(AiWriterCommand command) {
    return SizedBox(
      height: 30.0,
      child: FlowyButton(
        // leftIcon: FlowySvg(
        //   command.icon,
        //   size: const Size.square(16),
        // ),
        text: FlowyText(command.i18n),
        onTap: () {
          popoverController.close();
          insertAiNode(command);
        },
      ),
    );
  }

  Widget divider() {
    return const Divider(
      thickness: 1.0,
      height: 1.0,
    );
  }

  Widget buildChild() {
    final child = FlowyButton(
      text: FlowyText(
        LocaleKeys.document_plugins_smartEdit.tr(),
        fontSize: 14.0,
        figmaLineHeight: 20.0,
        color: Colors.white,
      ),
      hoverColor: Colors.transparent,
      useIntrinsicWidth: true,
      leftIcon: const FlowySvg(
        FlowySvgs.toolbar_item_ai_s,
        size: Size.square(16.0),
        color: Colors.white,
      ),
      iconPadding: 4.0,
      margin: const EdgeInsets.symmetric(
        horizontal: 4.0,
        vertical: 2.0,
      ),
      onTap: () {
        if (isAIEnabled) {
          keepEditorFocusNotifier.increase();
          popoverController.show();
        } else {
          showToastNotification(
            context,
            message: LocaleKeys.document_plugins_appflowyAIEditDisabled.tr(),
          );
        }
      },
    );

    return widget.tooltipBuilder?.call(
          context,
          _kAskAIToolbarItemId,
          isAIEnabled
              ? LocaleKeys.document_plugins_smartEdit.tr()
              : LocaleKeys.document_plugins_appflowyAIEditDisabled.tr(),
          child,
        ) ??
        child;
  }

  void insertAiNode(AiWriterCommand command) {
    final selection = widget.editorState.selection?.normalized;
    if (selection == null) {
      return;
    }

    final transaction = widget.editorState.transaction
      ..insertNode(
        selection.end.path.next,
        aiWriterNode(
          selection: selection,
          command: command,
        ),
      );

    widget.editorState.apply(
      transaction,
      options: const ApplyOptions(
        recordUndo: false,
        inMemoryUpdate: true,
      ),
      withUpdateSelection: false,
    );
  }

  bool get isAIEnabled {
    final documentContext = widget.editorState.document.root.context;
    return documentContext == null ||
        !documentContext.read<DocumentBloc>().isLocalMode;
  }
}