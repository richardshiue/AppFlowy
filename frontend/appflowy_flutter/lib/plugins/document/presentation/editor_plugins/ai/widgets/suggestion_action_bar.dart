import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

import '../operations/ai_writer_entities.dart';

class SuggestionActionBar extends StatelessWidget {
  const SuggestionActionBar({
    super.key,
    required this.showDecoration,
    required this.children,
  });

  final bool showDecoration;
  final List<SuggestionActionButton> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: showDecoration ? const EdgeInsets.all(4.0) : null,
      decoration: showDecoration ? _decoration(context) : null,
      child: SeparatedColumn(
        mainAxisSize: MainAxisSize.min,
        separatorBuilder: () => const HSpace(4.0),
        children: [
          FlowyText('hello world'),
        ],
      ),
    );
  }

  BoxDecoration _decoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(
        color: Theme.of(context).colorScheme.outline,
      ),
      borderRadius: const BorderRadius.all(Radius.circular(8.0)),
      boxShadow: const [
        BoxShadow(
          offset: Offset(0, 4),
          blurRadius: 20,
          color: Color(0x1A1F2329),
        ),
      ],
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
    return const Placeholder();
  }

  static EdgeInsetsGeometry get _padding =>
      const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0);
}
