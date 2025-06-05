import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

class SettingListTile extends StatelessWidget {
  const SettingListTile({
    super.key,
    this.resetTooltipText,
    this.resetButtonKey,
    required this.label,
    this.description = '',
    this.isCategory = false,
    this.trailing,
    this.onResetRequested,
  });

  final String label;
  final String description;
  final String? resetTooltipText;
  final Key? resetButtonKey;
  final bool isCategory;
  final List<Widget>? trailing;
  final VoidCallback? onResetRequested;

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
                VSpace(theme.spacing.xs),
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
        if (trailing != null) ...trailing!,
        if (onResetRequested != null)
          SettingsResetButton(
            key: resetButtonKey,
            resetTooltipText: resetTooltipText,
            onResetRequested: onResetRequested,
          ),
      ],
    );
  }
}

class SettingsResetButton extends StatelessWidget {
  const SettingsResetButton({
    super.key,
    this.resetTooltipText,
    this.onResetRequested,
  });

  final String? resetTooltipText;
  final VoidCallback? onResetRequested;

  @override
  Widget build(BuildContext context) {
    return FlowyIconButton(
      hoverColor: Theme.of(context).colorScheme.secondaryContainer,
      width: 24,
      icon: FlowySvg(
        FlowySvgs.restore_s,
        color: Theme.of(context).iconTheme.color,
        size: const Size.square(20),
      ),
      iconColorOnHover: Theme.of(context).colorScheme.onPrimary,
      tooltipText:
          resetTooltipText ?? LocaleKeys.settings_appearance_resetSetting.tr(),
      onPressed: onResetRequested,
    );
  }
}
