import 'dart:convert';

import 'package:appflowy/shared/markdown_to_document.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:synchronized/synchronized.dart';

const _enableDebug = false;

enum TextRobotEditSelectionStyle {
  replace,
  crossOutAndAppend,
  append,
}

class MarkdownTextRobot {
  MarkdownTextRobot({
    required this.editorState,
  });

  final EditorState editorState;

  final Lock lock = Lock();

  // The selection before the text robot starts
  Selection? _startSelection;

  // The markdown text to be inserted
  String _markdownText = '';

  // The nodes inserted in the previous refresh.
  Iterable<Node> _previousInsertedNodes = [];

  /// Only for debug via [_enableDebug].
  final List<String> debugMarkdownTexts = [];

  /// Start the text robot.
  ///
  /// Must call this function before using the text robot.
  void start({
    required TextRobotEditSelectionStyle editSelectionStyle,
  }) {
    _startSelection = editorState.selection;

    if (_enableDebug) {
      Log.info('MarkdownTextRobot start with selection: $_startSelection');
    }
  }

  /// Append the markdown text to the text robot.
  ///
  /// The text will be inserted into document but not persisted until the text
  /// robot is stopped.
  Future<void> appendMarkdownText(String text) async {
    _markdownText += text;

    await lock.synchronized(() async {
      await _refresh(inMemoryUpdate: true);
    });

    if (_enableDebug) {
      debugMarkdownTexts.add(text);
      Log.info(
        'MarkdownTextRobot receive markdown: ${jsonEncode(debugMarkdownTexts)}',
      );
    }
  }

  /// Stop the text robot.
  ///
  /// The text will be persisted into document.
  Future<void> stop() async {
    // persist the markdown text
    await lock.synchronized(() async {
      await _refresh(inMemoryUpdate: false);
    });

    _markdownText = '';

    if (_enableDebug) {
      Log.info('MarkdownTextRobot stop');
      debugMarkdownTexts.clear();
    }
  }

  /// Discard the inserted content
  Future<void> discard() async {
    final start = _startSelection?.start;
    if (start == null) {
      return;
    }

    if (_previousInsertedNodes.isEmpty) {
      return;
    }

    // fallback to the calculated position if the selection is null.
    final end = editorState.selection?.end ??
        Position(
          path: start.path.nextNPath(_previousInsertedNodes.length - 1),
        );
    final deletedNodes = editorState.getNodesInSelection(
      Selection(start: start, end: end),
    );
    final transaction = editorState.transaction
      ..deleteNodes(deletedNodes)
      ..afterSelection = _startSelection;

    await editorState.apply(
      transaction,
      options: const ApplyOptions(recordUndo: false),
    );

    if (_enableDebug) {
      Log.info('MarkdownTextRobot discard');
    }
  }

  void reset() {
    _previousInsertedNodes = [];
    _startSelection = null;
  }

  /// Refreshes the editor state with the current markdown text by:
  ///
  /// 1. Converting markdown to document nodes
  /// 2. Replacing previously inserted nodes with new nodes
  /// 3. Updating selection position
  Future<void> _refresh({
    required bool inMemoryUpdate,
  }) async {
    final start = _startSelection?.start;
    if (start == null) {
      return;
    }

    final transaction = editorState.transaction;

    // Convert markdown and deep copy nodes.
    // deep copy prevents the linked entities from being changed
    final nodes = customMarkdownToDocument(_markdownText, tableWidth: 250.0)
        .root
        .children
        .map((node) => node.deepCopy());

    // Insert new nodes at selection start
    transaction.insertNodes(start.path, nodes);

    // Remove previously inserted nodes if they exist
    if (_previousInsertedNodes.isNotEmpty) {
      // fallback to the calculated position if the selection is null.
      final end = editorState.selection?.end ??
          Position(
            path: start.path.nextNPath(_previousInsertedNodes.length - 1),
          );
      final deletedNodes = editorState.getNodesInSelection(
        Selection(start: start, end: end),
      );
      transaction.deleteNodes(deletedNodes);
    }

    // Update selection to end of inserted content if it contains text
    final lastDelta = nodes.lastOrNull?.delta;
    if (lastDelta != null) {
      transaction.afterSelection = Selection.collapsed(
        Position(
          path: start.path.nextNPath(nodes.length - 1),
          offset: lastDelta.length,
        ),
      );
    }

    await editorState.apply(
      transaction,
      options: ApplyOptions(
        inMemoryUpdate: inMemoryUpdate,
        recordUndo: false,
      ),
    );

    _previousInsertedNodes = nodes;
  }
}
