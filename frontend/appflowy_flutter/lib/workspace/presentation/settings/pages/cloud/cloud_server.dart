import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/settings/cloud_setting_bloc.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy/workspace/presentation/widgets/toggle/toggle.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppFlowySelfHostTip extends StatelessWidget {
  const AppFlowySelfHostTip({super.key});

  static const url =
      "https://docs.appflowy.io/docs/guides/appflowy/self-hosting-appflowy#build-appflowy-with-a-self-hosted-server";

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return RichText(
      text: TextSpan(
        style: theme.textStyle.caption.standard(
          color: theme.textColorScheme.secondary,
        ),
        children: <TextSpan>[
          TextSpan(
            text: "${LocaleKeys.settings_menu_selfHostStart.tr()} ",
          ),
          TextSpan(
            text: LocaleKeys.settings_menu_selfHostContent.tr(),
            style: TextStyle(
              color: theme.textColorScheme.action,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => afLaunchUrlString(url),
          ),
          TextSpan(
            text: " ${LocaleKeys.settings_menu_selfHostEnd.tr()}",
          ),
        ],
      ),
    );
  }
}

class AppFlowyCloudEnableSync extends StatelessWidget {
  const AppFlowyCloudEnableSync({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CloudSettingBloc, CloudSettingState>(
      builder: (context, state) {
        if (state is! ReadyCloudSettingState) {
          return const SizedBox.shrink();
        }

        return Row(
          children: [
            FlowyText.medium(LocaleKeys.settings_menu_enableSync.tr()),
            const Spacer(),
            Toggle(
              value: state.isSyncEnabled ?? false,
              onChanged: (value) => context
                  .read<CloudSettingBloc>()
                  .add(CloudSettingEvent.enableSync(value)),
            ),
          ],
        );
      },
    );
  }
}

class AppFlowyCloudEnableSyncLog extends StatelessWidget {
  const AppFlowyCloudEnableSyncLog({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CloudSettingBloc, CloudSettingState>(
      builder: (context, state) {
        if (state is! ReadyCloudSettingState) {
          return const SizedBox.shrink();
        }

        return Row(
          children: [
            FlowyText.medium(LocaleKeys.settings_menu_enableSyncLog.tr()),
            const Spacer(),
            Toggle(
              value: state.isSyncLogEnabled ?? false,
              onChanged: (value) {
                if (value) {
                  showCancelAndConfirmDialog(
                    context: context,
                    title: LocaleKeys.settings_menu_enableSyncLog.tr(),
                    description:
                        LocaleKeys.settings_menu_enableSyncLogWarning.tr(),
                    confirmLabel: LocaleKeys.button_confirm.tr(),
                    onConfirm: (_) {
                      context
                          .read<CloudSettingBloc>()
                          .add(CloudSettingEvent.enableSyncLog(value));
                    },
                  );
                } else {
                  context
                      .read<CloudSettingBloc>()
                      .add(CloudSettingEvent.enableSyncLog(value));
                }
              },
            ),
          ],
        );
      },
    );
  }
}
