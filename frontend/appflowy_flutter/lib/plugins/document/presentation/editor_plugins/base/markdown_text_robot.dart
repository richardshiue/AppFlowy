import 'dart:convert';

import 'package:appflowy/shared/markdown_to_document.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
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

  final Lock _lock = Lock();

  late TextRobotEditSelectionStyle _editSelectionStyle;

  /// The text position where new text will be inserted
  Position? _insertTextPosition;

  /// The selection before the text robot starts
  Selection? _startSelection;

  /// The markdown text to be inserted
  String _markdownText = '';

  /// The nodes inserted in the previous refresh.
  Iterable<Node> _previousInsertedNodes = [];

  /// Only for debug via [_enableDebug].
  final List<String> _debugMarkdownTexts = [];

  /// Start the text robot.
  ///
  /// Must call this function before using the text robot.
  Future<void> start({
    required TextRobotEditSelectionStyle editSelectionStyle,
    required Selection startSelection,
  }) async {
    _startSelection = startSelection;
    _editSelectionStyle = editSelectionStyle;

    await _initSelection();

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

    await _lock.synchronized(() async {
      await _refresh(inMemoryUpdate: true);
    });

    if (_enableDebug) {
      _debugMarkdownTexts.add(text);
      Log.info(
        'MarkdownTextRobot receive markdown: ${jsonEncode(_debugMarkdownTexts)}',
      );
    }
  }

  /// Stop the text robot.
  ///
  /// The text will be persisted into document.
  Future<void> stop() async {
    // persist the markdown text
    await _lock.synchronized(() async {
      await _refresh(inMemoryUpdate: false);
    });

    _markdownText = '';

    if (_enableDebug) {
      Log.info('MarkdownTextRobot stop');
      _debugMarkdownTexts.clear();
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
    _insertTextPosition = null;
  }

  Future<void> _initSelection() async {
    // null type promotion
    final selection = _startSelection;
    if (selection == null) {
      return;
    }

    if (_editSelectionStyle == TextRobotEditSelectionStyle.append) {
      _insertTextPosition = selection.start;
      return;
    }

    if (selection.isCollapsed) {
      _insertTextPosition = selection.start;
      return;
    }

    final nodes = editorState.getNodesInSelection(selection).toList();
    if (nodes.isEmpty) {
      _insertTextPosition = selection.start;
      return;
    }

    final isCrossOutAndAppend =
        _editSelectionStyle == TextRobotEditSelectionStyle.crossOutAndAppend;
    final isReplace =
        _editSelectionStyle == TextRobotEditSelectionStyle.replace;

    final transaction = editorState.transaction;

    if (nodes.length == 1) {
      final node = nodes.removeAt(0);

      final delta = Delta()..retain(selection.start.offset);
      if (isCrossOutAndAppend) {
        delta.retain(selection.length, attributes: {});
      } else if (isReplace) {
        delta.delete(selection.length);
      }

      transaction.addDeltaToComposeMap(node, delta);
    } else {
      // first node
      final firstNode = nodes.removeAt(0);
      final firstNodeDeltaLength =
          firstNode.delta!.toPlainText().characters.length;
      final firstNodeRemainderLength =
          firstNodeDeltaLength - selection.start.offset;

      final delta = Delta()..retain(selection.start.offset);
      if (isCrossOutAndAppend) {
        delta.retain(firstNodeRemainderLength, attributes: {});
      } else if (isReplace) {
        delta.delete(firstNodeRemainderLength);
      }
      transaction.addDeltaToComposeMap(firstNode, delta);

      // last node
      if (nodes.isNotEmpty) {
        final lastNode = nodes.removeLast();

        final delta = Delta();
        if (isCrossOutAndAppend) {
          delta.retain(selection.end.offset, attributes: {});
        } else if (isReplace) {
          delta.delete(selection.end.offset);
        }

        transaction.addDeltaToComposeMap(lastNode, delta);
      }

      // nodes in the middle
      for (final node in nodes) {
        if (node.type != ParagraphBlockKeys.type || node.delta == null) {
          continue;
        }
        final length = node.delta!.toPlainText().characters.length;
        if (length == 0) {
          continue;
        }

        final delta = Delta();
        if (isCrossOutAndAppend) {
          delta.retain(length, attributes: {});
        } else if (isReplace) {
          delta.delete(length);
        }

        transaction.addDeltaToComposeMap(node, delta);
      }
    }

    await editorState.apply(
      transaction,
      options: const ApplyOptions(
        inMemoryUpdate: true,
        recordUndo: false,
      ),
    );
  }

  /// Refreshes the editor state with `_markdownText` by:
  ///
  /// 1. Converting markdown to document nodes
  /// 2. Replacing previously inserted nodes with new nodes
  /// 3. Updating selection
  Future<void> _refresh({
    required bool inMemoryUpdate,
  }) async {
    final selection = _startSelection;
    if (selection == null) {
      return;
    }

    final isCrossOutAndAppend =
        _editSelectionStyle == TextRobotEditSelectionStyle.crossOutAndAppend;
    final isReplace =
        _editSelectionStyle == TextRobotEditSelectionStyle.replace;

    // Convert markdown and deep copy nodes.
    // deep copy prevents the linked entities from being changed
    final newNodes = customMarkdownToDocument(_markdownText, tableWidth: 250.0)
        .root
        .children
        .map((node) => node.deepCopy())
        .toList();

    final nodes = editorState.getNodesInSelection(selection).toList();
    if (nodes.isEmpty) {
      return;
    }

    final transaction = editorState.transaction;

    if (nodes.length == 1) {
      final node = nodes.removeAt(0);

      final delta = Delta()..retain(selection.start.offset);
      if (isCrossOutAndAppend) {
        delta.retain(selection.length);
      }
      delta.compose(node.delta!);

      transaction.addDeltaToComposeMap(node, delta);
    } else {}

    // Insert the nodes
    transaction.insertNodes(start.path, newNodes);

    // Remove previously-inserted nodes
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
    final lastDelta = newNodes.lastOrNull?.delta;
    if (lastDelta != null) {
      transaction.afterSelection = Selection.collapsed(
        Position(
          path: start.path.nextNPath(newNodes.length - 1),
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

    _previousInsertedNodes = newNodes;
  }
}
