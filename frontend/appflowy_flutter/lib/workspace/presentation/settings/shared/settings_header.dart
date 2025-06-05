import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/settings/prelude.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Renders a simple header for the settings view
///
class SettingsHeader extends StatelessWidget {
  const SettingsHeader({
    super.key,
    required this.page,
  });

  final SettingsPage page;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.spacing.xs,
      children: [
        Text(
          page.i18n,
          style: theme.textStyle.heading2.enhanced(
            color: theme.textColorScheme.primary,
          ),
        ),
        _Description(
          page: page,
        ),
      ],
    );
  }
}

class _Description extends StatelessWidget {
  const _Description({
    required this.page,
  });

  final SettingsPage page;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);
    final textStyle = theme.textStyle.caption.standard(
      color: theme.textColorScheme.secondary,
    );

    return switch (page) {
      SettingsPage.ai => Text(
          LocaleKeys.settings_aiPage_keys_aiSettingsDescription.tr(),
          style: textStyle,
          maxLines: 4,
        ),
      SettingsPage.workspace => Text(
          LocaleKeys.settings_workspacePage_description.tr(),
          style: textStyle,
          maxLines: 4,
        ),
      SettingsPage.manageData => Text(
          LocaleKeys.settings_manageDataPage_description.tr(),
          style: textStyle,
          maxLines: 4,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
