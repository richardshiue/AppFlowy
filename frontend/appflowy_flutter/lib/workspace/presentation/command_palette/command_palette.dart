import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/command_palette/command_palette_bloc.dart';
import 'package:appflowy/workspace/presentation/command_palette/widgets/recent_views_list.dart';
import 'package:appflowy/workspace/presentation/command_palette/widgets/search_field.dart';
import 'package:appflowy/workspace/presentation/command_palette/widgets/search_results_list.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';

class _ToggleCommandPaletteIntent extends Intent {
  const _ToggleCommandPaletteIntent();
}

class CommandPalette extends StatelessWidget {
  const CommandPalette({
    super.key,
    required this.child,
  });

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (child == null) {
      return const SizedBox.shrink();
    }

    return BlocListener<CommandPaletteBloc, CommandPaletteState>(
      listenWhen: (previous, current) =>
          previous.isShowing != current.isShowing,
      listener: (context, state) {
        _onToggle(context, state.isShowing);
      },
      child: _CommandPaletteShortcuts(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }

  void _onToggle(BuildContext context, bool isShowing) async {
    if (isShowing) {
      await FlowyOverlay.show(
        context: context,
        builder: (_) => BlocProvider.value(
          value: context.read<CommandPaletteBloc>(),
          child: const CommandPaletteModal(),
        ),
      );
      return;
    }
    FlowyOverlay.pop(context);
  }
}

class _CommandPaletteShortcuts extends StatelessWidget {
  const _CommandPaletteShortcuts({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      actions: {
        _ToggleCommandPaletteIntent:
            CallbackAction<_ToggleCommandPaletteIntent>(
          onInvoke: (intent) {
            context
                .read<CommandPaletteBloc>()
                .add(const CommandPaletteEvent.toggle());
            return;
          },
        ),
      },
      shortcuts: {
        LogicalKeySet(
          UniversalPlatform.isMacOS
              ? LogicalKeyboardKey.meta
              : LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyP,
        ): const _ToggleCommandPaletteIntent(),
      },
      child: child,
    );
  }
}

class CommandPaletteModal extends StatelessWidget {
  const CommandPaletteModal({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommandPaletteBloc, CommandPaletteState>(
      builder: (context, state) {
        return FlowyDialog(
          alignment: Alignment.topCenter,
          insetPadding: const EdgeInsets.only(top: 100),
          constraints: const BoxConstraints(
            maxHeight: 600,
            maxWidth: 800,
            minHeight: 600,
          ),
          expandHeight: false,
          child: _CommandPaletteShortcuts(
            child: Column(
              children: [
                SearchField(query: state.query, isLoading: state.searching),
                if (state.query?.isEmpty ?? true) ...[
                  const Divider(height: 0),
                  Flexible(
                    child: RecentViewsList(
                      onSelected: () => FlowyOverlay.pop(context),
                    ),
                  ),
                ],
                if (state.combinedResponseItems.isNotEmpty &&
                    (state.query?.isNotEmpty ?? false)) ...[
                  const Divider(height: 0),
                  Flexible(
                    child: SearchResultList(
                      trash: state.trash,
                      resultItems: state.combinedResponseItems.values.toList(),
                      resultSummaries: state.resultSummaries,
                    ),
                  ),
                ]
                // When there are no results and the query is not empty and not loading,
                // show the no results message, centered in the available space.
                else if ((state.query?.isNotEmpty ?? false) &&
                    !state.searching) ...[
                  const Divider(height: 0),
                  Expanded(
                    child: const _NoResultsHint(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Updated _NoResultsHint now centers its content.
class _NoResultsHint extends StatelessWidget {
  const _NoResultsHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FlowyText.regular(
        LocaleKeys.commandPalette_noResultsHint.tr(),
        textAlign: TextAlign.center,
      ),
    );
  }
}
