import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

import '../operations/ai_writer_entities.dart';

class SuggestionActionBar extends StatelessWidget {
  const SuggestionActionBar({
    super.key,
    required this.actions,
  });

  final List<SuggestionAction> actions;

  @override
  Widget build(BuildContext context) {
    return SeparatedRow(
      mainAxisSize: MainAxisSize.min,
      separatorBuilder: () => const HSpace(4.0),
      children: actions
          .map(
            (action) => SuggestionActionButton(
              action: action,
              onTap: () {},
            ),
          )
          .toList(),
    );
  }
}

class SuggestionActionButton extends StatelessWidget {
  const SuggestionActionButton({
    super.key,
    required this.action,
    required this.onTap,
  });

  final SuggestionAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      child: FlowyText(action.i18n),
    );
  }
}
