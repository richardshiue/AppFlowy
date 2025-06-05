import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/settings/notifications/notification_settings_cubit.dart';
import 'package:appflowy/workspace/presentation/settings/shared/setting_list_tile.dart';
import 'package:appflowy/workspace/presentation/widgets/toggle/toggle.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsNotificationsView extends StatelessWidget {
  const SettingsNotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return BlocBuilder<NotificationSettingsCubit, NotificationSettingsState>(
      builder: (context, state) {
        return SeparatedColumn(
          separatorBuilder: () => AFDivider(spacing: theme.spacing.xl),
          children: [
            SettingListTile(
              label: LocaleKeys.settings_notifications_enableNotifications_label
                  .tr(),
              description: LocaleKeys
                  .settings_notifications_enableNotifications_hint
                  .tr(),
              isCategory: true,
              trailing: [
                Toggle(
                  value: state.isNotificationsEnabled,
                  onChanged: (_) => context
                      .read<NotificationSettingsCubit>()
                      .toggleNotificationsEnabled(),
                ),
              ],
            ),
            SettingListTile(
              label: LocaleKeys
                  .settings_notifications_showNotificationsIcon_label
                  .tr(),
              description: LocaleKeys
                  .settings_notifications_showNotificationsIcon_hint
                  .tr(),
              isCategory: true,
              trailing: [
                Toggle(
                  value: state.isShowNotificationsIconEnabled,
                  onChanged: (_) => context
                      .read<NotificationSettingsCubit>()
                      .toggleShowNotificationIconEnabled(),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
