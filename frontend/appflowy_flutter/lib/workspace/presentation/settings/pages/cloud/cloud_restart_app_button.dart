import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/user/presentation/screens/sign_in_screen/widgets/sign_in_or_logout_button.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:universal_platform/universal_platform.dart';

class RestartButton extends StatelessWidget {
  const RestartButton({
    super.key,
    required this.showRestartHint,
    this.isDisabled = false,
    required this.onTap,
  });

  final bool showRestartHint;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.spacing.m,
      children: [
        if (UniversalPlatform.isDesktopOrWeb)
          AFFilledTextButton.primary(
            disabled: isDisabled,
            text: LocaleKeys.settings_menu_restartApp.tr(),
            onTap: onTap,
          )
        else
          MobileLogoutButton(
            text: LocaleKeys.settings_menu_restartApp.tr(),
            onPressed: onTap,
          ),
        if (showRestartHint)
          Text(
            LocaleKeys.settings_menu_restartAppTip.tr(),
            style: theme.textStyle.caption.standard(
              color: theme.textColorScheme.secondary,
            ),
          ),
      ],
    );
  }
}
