import 'package:appflowy/plugins/ai_chat/application/chat_select_sources_cubit.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/presentation/home/menu/view/view_item.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:flowy_infra/theme_extension.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/hover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'chat_mention_page_menu.dart';

/// amount of padding to the left of the tree item that increases with deeper
/// levels
const double _levelSpacing = 20.0;

class PromptInputSelectSourcesButton extends StatelessWidget {
  const PromptInputSelectSourcesButton({
    super.key,
    required this.chatId,
  });

  final String chatId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChatSettingsCubit(chatId: chatId),
      child: Builder(
        builder: (context) {
          return AppFlowyPopover(
            constraints: BoxConstraints.loose(const Size(320, 380)),
            popupBuilder: (_) {
              return BlocProvider.value(
                value: context.read<ChatSettingsCubit>(),
                child: const _PopoverContent(),
              );
            },
            child: BlocBuilder<ChatSettingsCubit, ChatSettingsState>(
              builder: (context, state) {
                return Container(width: 50, height: 40, color: Colors.red);
              },
            ),
          );
        },
      ),
    );
  }
}

class _IndicatorButton extends StatelessWidget {
  const _IndicatorButton();

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class _PopoverContent extends StatelessWidget {
  const _PopoverContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatSettingsCubit, ChatSettingsState>(
      builder: (context, state) {
        return const SizedBox.shrink();
      },
    );
  }
}

class ViewItem extends StatefulWidget {
  const ViewItem({
    super.key,
    required this.chatSource,
    required this.level,
    this.onSelected,
    this.visibilityGetter,
  });

  final ChatSource chatSource;

  /// nested level of the view item
  final int level;

  /// Selected by normal conventions
  final void Function(ViewPB view)? onSelected;

  final IgnoreViewType Function(ViewPB view)? visibilityGetter;

  @override
  State<ViewItem> createState() => _ViewItemState();
}

class _ViewItemState extends State<ViewItem> {
  @override
  Widget build(BuildContext context) {
    final child = SingleInnerViewItem(
      chatSource: widget.chatSource,
      level: widget.level,
      onSelected: widget.onSelected,
    );

    final viewVisibility =
        widget.visibilityGetter?.call(widget.chatSource.view) ??
            IgnoreViewType.none;

    final disabledEnabledChild = viewVisibility == IgnoreViewType.disable
        ? Opacity(
            opacity: 0.5,
            child: MouseRegion(
              cursor: SystemMouseCursors.forbidden,
              child: IgnorePointer(child: child),
            ),
          )
        : child;

    // filter the child views that should be ignored
    final childViews = [...widget.chatSource.children];
    if (widget.visibilityGetter != null) {
      childViews.retainWhere(
        (v) => widget.visibilityGetter!(v) != IgnoreViewType.hide,
      );
    }

    if (!widget.chatSource.isExpanded || childViews.isEmpty) {
      return disabledEnabledChild;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        disabledEnabledChild,
        ...childViews.map(
          (childSource) => ViewItem(
            key: ValueKey('select_sources_tree_item_${childSource.view.id}'),
            chatSource: childSource,
            level: widget.level + 1,
            onSelected: widget.onSelected,
          ),
        ),
      ],
    );
  }
}

class SingleInnerViewItem extends StatelessWidget {
  const SingleInnerViewItem({
    super.key,
    required this.chatSource,
    required this.level,
    this.onSelected,
  });

  final ChatSource chatSource;
  final int level;
  final void Function(ViewPB view)? onSelected;

  @override
  Widget build(BuildContext context) {
    return FlowyHover(
      style: HoverStyle(
        hoverColor: AFThemeExtension.of(context).lightGreyHover,
      ),
      builder: (_, onHover) => _buildViewItem(onHover),
    );
  }

  Widget _buildViewItem(bool onHover) {
    final children = [
      HSpace(level * _levelSpacing),
      // expand icon or placeholder
      _buildToggleButton(),
      const HSpace(2),
      // checkbox
      _buildSelectedStateButton(),
      const HSpace(4),
      // icon
      _buildViewIconButton(),
      const HSpace(4),
      // title
      Expanded(
        child: FlowyText(
          chatSource.view.nameOrDefault,
          overflow: TextOverflow.ellipsis,
          fontSize: 14.0,
          figmaLineHeight: 18.0,
        ),
      ),
    ];

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => onSelected?.call(view),
      child: SizedBox(
        height: 30.0,
        child: Row(
          children: children,
        ),
      ),
    );
  }

  // builds the >, ^ or · button
  Widget _buildToggleButton() {
    return ViewItemDefaultLeftIcon(
      view: view,
      parentView: parentView,
      isExpanded: isExpanded,
      leftPadding: _levelSpacing,
      isHovered: null,
    );
  }

  Widget _buildSelectedStateButton() {
    return ViewItemDefaultLeftIcon(
      view: view,
      parentView: parentView,
      isExpanded: isExpanded,
      leftPadding: _levelSpacing,
      isHovered: null,
    );
  }

  Widget _buildViewIconButton() {
    return MentionViewIcon(view: view);
  }
}
