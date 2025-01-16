import 'dart:convert';

import 'package:appflowy/shared/markdown_to_document.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:synchronized/synchronized.dart';

const _enableDebug = false;

class MarkdownTextRobot {
  MarkdownTextRobot({
    required this.editorState,
  });

  final EditorState editorState;

  final Lock _lock = Lock();

  /// The text position where new nodes will be inserted
  Position? _insertPosition;

  /// The markdown text to be inserted
  String _markdownText = '';

  /// The nodes inserted in the previous refresh.
  Iterable<Node> _insertedNodes = [];

  /// Only for debug via [_enableDebug].
  final List<String> _debugMarkdownTexts = [];

  bool get hasAnyResult => _markdownText.isNotEmpty;

  Selection? getInsertedSelection() {
    final position = _insertPosition;
    if (position == null) {
      Log.error("Expected non-null insert markdown text position");
      return null;
    }

    if (_insertedNodes.isEmpty) {
      return Selection.collapsed(position);
    }
    return Selection(
      start: position,
      end: Position(path: position.path.nextNPath(_insertedNodes.length - 1)),
    );
  }

  List<Node> getInsertedNodes() {
    final selection = getInsertedSelection();
    return selection == null ? [] : editorState.getNodesInSelection(selection);
  }

  /// This function must be called before
  void start() {
    _insertPosition = editorState.selection?.start;

    if (_enableDebug) {
      Log.info(
        'MarkdownTextRobot start with insert text position: $_insertPosition',
      );
    }
  }

  /// The text will be inserted into the document but only in memory
  Future<void> appendMarkdownText(
    String text, {
    Map<String, dynamic>? attributes,
  }) async {
    _markdownText += text;

    await _lock.synchronized(() async {
      await _refresh(
        inMemoryUpdate: true,
        attributes: attributes,
      );
    });

    if (_enableDebug) {
      _debugMarkdownTexts.add(text);
      Log.info(
        'MarkdownTextRobot receive markdown: ${jsonEncode(_debugMarkdownTexts)}',
      );
    }
  }

  /// Persist the text into the document
  Future<void> persist() async {
    await _lock.synchronized(() async {
      await _refresh(inMemoryUpdate: false);
    });

    if (_enableDebug) {
      Log.info('MarkdownTextRobot stop');
      _debugMarkdownTexts.clear();
    }
  }

  /// Discard the inserted content
  Future<void> discard() async {
    final start = _insertPosition;
    if (start == null) {
      return;
    }
    if (_insertedNodes.isEmpty) {
      return;
    }

    // fallback to the calculated position if the selection is null.
    final end = Position(
      path: start.path.nextNPath(_insertedNodes.length - 1),
    );
    final deletedNodes = editorState.getNodesInSelection(
      Selection(start: start, end: end),
    );
    final transaction = editorState.transaction
      ..deleteNodes(deletedNodes)
      ..afterSelection = Selection.collapsed(start);

    await editorState.apply(
      transaction,
      options: const ApplyOptions(recordUndo: false),
    );

    if (_enableDebug) {
      Log.info('MarkdownTextRobot discard');
    }
  }

  void reset() {
    _markdownText = '';
    _insertedNodes = [];
    _insertPosition = null;
  }

  Future<void> _refresh({
    required bool inMemoryUpdate,
    Map<String, dynamic>? attributes,
  }) async {
    final position = _insertPosition;
    if (position == null) {
      Log.error("Expected non-null insert markdown text position");
      return;
    }

    final node = editorState.getNodeAtPath(position.path);
    if (node == null) {
      Log.error("Cannot find node at position: ${position.path}");
      return;
    }

    // Convert markdown and deep copy the nodes, prevent ing the linked
    // entities from being changed
    final newNodes = customMarkdownToDocument(
      _markdownText,
      tableWidth: 250.0,
    ).root.children.map(
      (node) {
        final isParagraph =
            node.type == ParagraphBlockKeys.type && node.delta != null;
        if (isParagraph && attributes != null) {
          final delta = node.delta!;
          final attributeDelta = Delta()
            ..retain(delta.length, attributes: attributes);
          final newDelta = delta.compose(attributeDelta);
          final newAttributes = node.attributes;
          newAttributes['delta'] = newDelta.toJson();
          node.updateAttributes(newAttributes);
        }
        return node.deepCopy();
      },
    ).toList();

    if (newNodes.isEmpty) {
      return;
    }
    final transaction = editorState.transaction
      ..insertNodes(position.path, newNodes)
      ..deleteNodes(getInsertedNodes());

    await editorState.apply(
      transaction,
      options: ApplyOptions(
        inMemoryUpdate: inMemoryUpdate,
        recordUndo: false,
      ),
      withUpdateSelection: false,
    );

    _insertedNodes = newNodes;
  }
}
