import 'package:appflowy/shared/markdown_to_document.dart';
import 'package:appflowy_editor/appflowy_editor.dart';

import '../ai_writer_block_component.dart';
import 'ai_writer_entities.dart';

extension AIWriterNodeExtension on EditorState {
  // /// Update the prompt text in the node
  // Future<void> updatePromptText(Node aiWriterNode, String prompt) async {
  //   final transaction = this.transaction
  //     ..updateNode(
  //       aiWriterNode,
  //       {AIWriterBlockKeys.userPrompt: prompt},
  //     );
  //   await apply(
  //     transaction,
  //     options: const ApplyOptions(
  //       inMemoryUpdate: true,
  //       recordUndo: false,
  //     ),
  //   );
  // }

  // /// Update the generation count in the node
  // Future<void> updateGenerationCount(Node aiWriterNode, int count) async {
  //   final transaction = this.transaction
  //     ..updateNode(
  //       aiWriterNode,
  //       {AIWriterBlockKeys.generationCount: count},
  //     );
  //   await apply(
  //     transaction,
  //     options: const ApplyOptions(inMemoryUpdate: true),
  //   );
  // }

  Future<void> removeAiWriterNode(Node node) async {
    final transaction = this.transaction..deleteNode(node);
    await apply(
      transaction,
      options: const ApplyOptions(inMemoryUpdate: true, recordUndo: false),
      withUpdateSelection: false,
    );
  }
}

extension SaveAIResponseExtension on EditorState {
  /// Ensure the previous node is a empty paragraph node without any styles
  Future<void> ensurePreviousNodeIsEmptyParagraphNode(Node aiWriterNode) async {
    final previous = aiWriterNode.previous;
    final Selection selection;
    final transaction = this.transaction;

    final needsEmptyParagraphNode = previous == null ||
        previous.type != ParagraphBlockKeys.type ||
        (previous.delta?.toPlainText().isNotEmpty ?? false);

    if (needsEmptyParagraphNode) {
      selection = Selection.collapsed(Position(path: aiWriterNode.path));
      transaction.insertNode(aiWriterNode.path, paragraphNode());
    } else {
      selection = Selection.collapsed(Position(path: previous.path));
    }

    transaction
      ..updateNode(
        aiWriterNode,
        {
          AIWriterBlockKeys.selection: selection.toJson(),
          AIWriterBlockKeys.isInitialized: true,
        },
      )
      ..afterSelection = selection;

    await apply(
      transaction,
      options: const ApplyOptions(inMemoryUpdate: true),
    );
  }

  Future<void> ensureSelectionIsInParagraph(
    Node aiWriterNode,
    Selection selection,
  ) async {
    final currentNode = getNodeAtPath(selection.end.path);
    final needsEmptyParagraphNode =
        currentNode == null || currentNode.type != ParagraphBlockKeys.type;

    final transaction = this.transaction;
    Selection afterSelection = selection;

    if (needsEmptyParagraphNode) {
      transaction.insertNode(aiWriterNode.path, paragraphNode());
      afterSelection = Selection.collapsed(Position(path: aiWriterNode.path));
    }

    transaction.updateNode(
      aiWriterNode,
      {
        AIWriterBlockKeys.selection: afterSelection.toJson(),
        AIWriterBlockKeys.isInitialized: true,
      },
    );

    await apply(
      transaction,
      options: const ApplyOptions(inMemoryUpdate: true),
    );
  }

  Future<void> insertBelow({
    required Node node,
    required String markdownText,
  }) async {
    final selection = this.selection?.normalized;
    if (selection == null) {
      return;
    }

    final nodes = customMarkdownToDocument(markdownText)
        .root
        .children
        .map((e) => e.deepCopy())
        .toList();
    if (nodes.isEmpty) {
      return;
    }

    final insertedPath = selection.end.path.next;
    final lastDeltaLength = nodes.lastOrNull?.delta?.length ?? 0;

    final transaction = this.transaction
      ..insertNodes(insertedPath, nodes)
      ..afterSelection = Selection(
        start: Position(path: insertedPath),
        end: Position(
          path: insertedPath.nextNPath(nodes.length - 1),
          offset: lastDeltaLength,
        ),
      );

    await apply(transaction);
  }

  Future<void> replace({
    required String text,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }
    await switch (kdefaultReplacementType) {
      AskAIReplacementType.markdown => _replaceWithMarkdown(trimmedText),
      AskAIReplacementType.plainText => _replaceWithPlainText(trimmedText),
    };
  }

  Future<void> _replaceWithMarkdown(String markdownText) async {
    final selection = this.selection?.normalized;
    if (selection == null) {
      return;
    }

    final nodes = customMarkdownToDocument(markdownText)
        .root
        .children
        .map((e) => e.deepCopy())
        .toList();
    if (nodes.isEmpty) {
      return;
    }

    final nodesInSelection = getNodesInSelection(selection);
    final newSelection = Selection(
      start: selection.start,
      end: Position(
        path: selection.start.path.nextNPath(nodes.length - 1),
        offset: nodes.lastOrNull?.delta?.length ?? 0,
      ),
    );

    final transaction = this.transaction
      ..insertNodes(selection.start.path, nodes)
      ..deleteNodes(nodesInSelection)
      ..afterSelection = newSelection;
    await apply(transaction);
  }

  Future<void> _replaceWithPlainText(String plainText) async {
    final selection = this.selection?.normalized;
    if (selection == null) {
      return;
    }
    final nodes = getNodesInSelection(selection);
    if (nodes.isEmpty || nodes.any((element) => element.delta == null)) {
      return;
    }

    final replaceTexts = plainText.split('\n')
      ..removeWhere((element) => element.isEmpty);
    final transaction = this.transaction
      ..replaceTexts(
        nodes,
        selection,
        replaceTexts,
      );
    await apply(transaction);

    int endOffset = replaceTexts.last.length;
    if (replaceTexts.length == 1) {
      endOffset += selection.start.offset;
    }
    final end = Position(
      path: [selection.start.path.first + replaceTexts.length - 1],
      offset: endOffset,
    );
    this.selection = Selection(
      start: selection.start,
      end: end,
    );
  }

  // Future<void> _exit() async {
  //   final transaction = editorState.transaction..deleteNode(node);
  //   await editorState.apply(
  //     transaction,
  //     options: const ApplyOptions(
  //       recordUndo: false,
  //     ),
  //   );
  // }

  /// Discard the current response and delete the previous node.
  Future<void> discardCurrentResponse({
    required Node aiWriterNode,
    Selection? selection,
  }) async {
    if (selection == null) {
      return;
    }
    final start = selection.start.path;
    final end = aiWriterNode.previous?.path;
    if (end != null) {
      final transaction = this.transaction
        ..deleteNodesAtPath(
          start,
          end.last - start.last + 1,
        );
      await apply(transaction);
      await ensurePreviousNodeIsEmptyParagraphNode(aiWriterNode);
    }
  }
}
