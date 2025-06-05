import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';

/// This is used to describe a single setting action
///
/// This will render a simple action that takes the title,
/// the button label, and the button action.
///
class SingleSettingAction extends StatelessWidget {
  const SingleSettingAction({
    super.key,
    required this.label,
    this.description = '',
    required this.buttonLabel,
    this.isCategory = false,
    this.isDestructive = false,
    this.isDisabled = false,
    required this.onTap,
  });

  final String label;
  final String description;
  final String buttonLabel;

  final bool isCategory;
  final bool isDestructive;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    final categoryTitleTextStyle = theme.textStyle.heading4.enhanced(
      color: theme.textColorScheme.primary,
    );
    final bodyTextStyle = theme.textStyle.body.enhanced(
      color: theme.textColorScheme.primary,
    );
    final captionTextStyle = theme.textStyle.caption.standard(
      color: theme.textColorScheme.secondary,
    );

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: isCategory ? categoryTitleTextStyle : bodyTextStyle,
                overflow: TextOverflow.ellipsis,
              ),
              if (description.isNotEmpty) ...[
                const VSpace(4),
                Text(
                  description,
                  style: captionTextStyle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ],
          ),
        ),
        const HSpace(24),
        if (isDestructive)
          AFOutlinedTextButton.destructive(
            text: buttonLabel,
            onTap: onTap,
            disabled: isDisabled,
          )
        else
          AFFilledTextButton.primary(
            text: buttonLabel,
            onTap: onTap,
            disabled: isDisabled,
          ),
      ],
    );
  }
}
