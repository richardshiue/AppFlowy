import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/widgets.dart';

export 'dimension.dart';

class AFModal extends StatelessWidget {
  const AFModal({
    super.key,
    required this.headerBuilder,
    required this.bodyBuilder,
    required this.footerBuilder,
  });

  final WidgetBuilder? headerBuilder;
  final WidgetBuilder bodyBuilder;
  final WidgetBuilder? footerBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: theme.shadow.medium,
        borderRadius: BorderRadius.circular(theme.borderRadius.xl),
        color: theme.surfaceColorScheme.primary,
      ),
      child: Column(
        children: [
          headerBuilder?.call(context),
          Expanded(
            child: SingleChildScrollView(
              child: bodyBuilder(context),
            ),
          ),
          footerBuilder?.call(context),
        ].nonNulls.toList(),
      ),
    );
  }
}

class AFModalHeader extends StatelessWidget {
  const AFModalHeader({
    super.key,
    required this.title,
    required this.onClose,
  });

  final Widget title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        top: theme.spacing.xl,
        left: theme.spacing.xxl,
        right: theme.spacing.xxl,
      ),
      child: Row(
        spacing: theme.spacing.s,
        children: [
          Expanded(child: title),
          AFGhostButton.normal(
            onTap: onClose,
            builder: (context, isHovering, disabled) {
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

class AFModalFooter extends StatelessWidget {
  const AFModalFooter({
    super.key,
    this.bottomStartActions = const [],
    this.bottomEndActions = const [],
  });

  final List<Widget> bottomStartActions;
  final List<Widget> bottomEndActions;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: theme.spacing.xl,
        left: theme.spacing.xxl,
        right: theme.spacing.xxl,
      ),
      child: Row(
        spacing: theme.spacing.l,
        children: [
          ...bottomStartActions,
          Spacer(),
          ...bottomEndActions,
        ],
      ),
    );
  }
}
