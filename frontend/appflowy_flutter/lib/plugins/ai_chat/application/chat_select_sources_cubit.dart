import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_select_sources_cubit.freezed.dart';

enum SourceSelectedStatus {
  unselected,
  selected,
  partiallySelected;

  bool get isUnselected => this == unselected;
  bool get isSelected => this == selected;
  bool get isPartiallySelected => this == partiallySelected;
}

class ChatSource {
  ChatSource({
    required this.view,
    required this.parentView,
    required this.children,
    required this.isExpanded,
    required this.selectedStatus,
  });

  final ViewPB view;
  final ViewPB? parentView;
  final List<ChatSource> children;
  final bool isExpanded;
  final SourceSelectedStatus selectedStatus;
}

class ChatSettingsCubit extends Cubit<ChatSettingsState> {
  ChatSettingsCubit({required this.chatId})
      : super(ChatSettingsState.initial());
  final String chatId;

  Future<ChatSource> _recursiveBuild(ViewPB view, ViewPB? parentView) async {
    SourceSelectedStatus selectedStatus = SourceSelectedStatus.unselected;

    final childrenViews =
        await ViewBackendService.getChildViews(viewId: view.id).toNullable();

    int selectedCount = 0;
    final children = <ChatSource>[];

    if (childrenViews != null && childrenViews.isNotEmpty) {
      for (final childView in childrenViews) {
        final childChatSource = await _recursiveBuild(childView, view);

        if (childChatSource.selectedStatus.isSelected) {
          selectedCount++;
        }

        if ((childChatSource.selectedStatus.isPartiallySelected ||
                childChatSource.selectedStatus.isSelected) &&
            selectedStatus.isUnselected) {
          selectedStatus = SourceSelectedStatus.partiallySelected;
        }

        children.add(childChatSource);
      }

      if ([].contains(view.id)) {
        // if (selectedViewIds.contains(view.id)) {
        if (children.length == selectedCount) {
          selectedStatus = SourceSelectedStatus.selected;
        } else {
          selectedStatus = SourceSelectedStatus.partiallySelected;
        }
      }
    }

    return ChatSource(
      view: view,
      parentView: parentView,
      children: children,
      isExpanded: false,
      selectedStatus: selectedStatus,
    );
  }

  /// traverse tree to build up search query
  ChatSource? _buildSearchResults(ChatSource chatSource) {
    final isVisible =
        chatSource.view.name.toLowerCase().contains("".toLowerCase());
    // chatSource.view.name.toLowerCase().contains(filter.toLowerCase());

    final childrenResults = <ChatSource>[];
    for (final childSource in chatSource.children) {
      final childResult = _buildSearchResults(childSource);
      if (childResult != null) {
        childrenResults.add(childResult);
      }
    }

    return isVisible || childrenResults.isNotEmpty
        ? ChatSource(
            view: chatSource.view,
            parentView: chatSource.parentView,
            children: childrenResults,
            isExpanded: true,
            selectedStatus: chatSource.selectedStatus,
          )
        : null;
  }

  /// traverse tree to build up selected sources
  Iterable<ChatSource> _buildSelectedSources(ChatSource chatSource) {
    final children = <ChatSource>[];

    for (final childSource in chatSource.children) {
      children.addAll(_buildSelectedSources(childSource));
    }

    return chatSource.selectedStatus.isUnselected
        ? children
        : [
            ChatSource(
              view: chatSource.view,
              parentView: chatSource.parentView,
              children: children,
              selectedStatus: chatSource.selectedStatus,
              isExpanded: true,
            ),
          ];
  }
}

@freezed
class ChatSettingsState with _$ChatSettingsState {
  factory ChatSettingsState({
    required List<String> selectedViewIds,
  }) = _ChatSettingsState;

  factory ChatSettingsState.initial() => ChatSettingsState(selectedViewIds: []);
}
