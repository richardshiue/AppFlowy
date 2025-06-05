import 'package:appflowy/env/cloud_env.dart';
import 'package:appflowy/env/env.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/auth/auth_service.dart';
import 'package:appflowy/workspace/application/settings/cloud_setting_bloc.dart';
import 'package:appflowy/workspace/application/settings/prelude.dart';
import 'package:appflowy/workspace/presentation/widgets/dialog_v2.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:universal_platform/universal_platform.dart';

import '../../shared/settings_body.dart';
import 'cloud_restart_app_button.dart';
import 'cloud_self_host_input.dart';
import 'cloud_server.dart';
import 'cloud_type_switcher.dart';

class SettingCloudView extends StatefulWidget {
  const SettingCloudView({
    super.key,
  });

  @override
  State<SettingCloudView> createState() => _SettingCloudViewState();
}

class _SettingCloudViewState extends State<SettingCloudView> {
  final serverUrlTextController = TextEditingController();
  final webBaseDomainTextController = TextEditingController();

  @override
  void dispose() {
    serverUrlTextController.dispose();
    webBaseDomainTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        return CloudSettingBloc()..add(CloudSettingEvent.initial());
      },
      child: MultiBlocListener(
        listeners: [
          BlocListener<CloudSettingBloc, CloudSettingState>(
            listener: (context, state) {
              if (state is RestartCloudSettingState) {
                restartAppFlowy(context);
              }
            },
          ),
          BlocListener<CloudSettingBloc, CloudSettingState>(
            listenWhen: (previous, current) =>
                switch (previous) {
                  final ReadyCloudSettingState state => state.customCloudConfig,
                  _ => null
                } !=
                switch (current) {
                  final ReadyCloudSettingState state => state.customCloudConfig,
                  _ => null
                },
            listener: (context, state) {
              if (state is ReadyCloudSettingState &&
                  state.customCloudConfig != null) {
                serverUrlTextController.text =
                    state.customCloudConfig!.base_url;
                webBaseDomainTextController.text =
                    state.customCloudConfig!.base_web_domain;
              } else {
                serverUrlTextController.clear();
                webBaseDomainTextController.clear();
              }
            },
          ),
        ],
        child: BlocBuilder<CloudSettingBloc, CloudSettingState>(
          builder: (context, state) {
            if (state is! ReadyCloudSettingState) {
              return const Center(
                child: CircularProgressIndicator.adaptive(),
              );
            }

            return SettingsBody(
              page: SettingsPage.cloud,
              separatorBuilder: () => AFDivider(
                spacing: AppFlowyTheme.of(context).spacing.xl,
              ),
              children: [
                if (Env.enableCustomCloud)
                  CloudServerSwitcher(cloudType: state.cloudType),
                if (state.cloudType.isAppFlowyCloudEnabled &&
                    state.workspaceType == WorkspaceTypePB.ServerW)
                  const AppFlowyCloudEnableSync(),
                // if (state.cloudType.isAppFlowyCloudEnabled &&
                //     state.workspaceType == WorkspaceTypePB.ServerW)
                //   const AppFlowyCloudEnableSyncLog(),
                if (state.cloudType ==
                        AuthenticatorType.appflowyCloudSelfHost &&
                    state.customCloudConfig != null)
                  CloudSelfHostInput(
                    serverUrlTextController: serverUrlTextController,
                    webBaseDomainTextController: webBaseDomainTextController,
                  ),
                ValueListenableBuilder(
                  valueListenable: serverUrlTextController,
                  builder: (context, serverUrl, _) {
                    return ValueListenableBuilder(
                      valueListenable: webBaseDomainTextController,
                      builder: (context, webBaseDomain, _) {
                        final isDisabled = state.cloudType ==
                                AuthenticatorType.appflowyCloudSelfHost &&
                            (serverUrl.text.isEmpty ||
                                webBaseDomain.text.isEmpty);

                        return RestartButton(
                          isDisabled: isDisabled,
                          showRestartHint:
                              state.cloudType.isAppFlowyCloudEnabled,
                          onTap: () => handleClickRestart(context),
                        );
                      },
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void handleClickRestart(
    BuildContext context,
  ) {
    showSimpleAFDialog(
      context: context,
      title: LocaleKeys.settings_menu_restartApp.tr(),
      content: LocaleKeys.settings_menu_restartAppTip.tr(),
      primaryAction: (
        LocaleKeys.button_confirm.tr(),
        (_) {
          final serverUrl = serverUrlTextController.text.trim();
          final webBaseDomain = webBaseDomainTextController.text.trim();

          context.read<CloudSettingBloc>().add(
                RestartCloudSettingEvent(
                  serverUrl: serverUrl,
                  baseWebDomain: webBaseDomain,
                ),
              );
        }
      ),
      secondaryAction: (LocaleKeys.button_cancel.tr(), (_) {}),
    );
  }

  void restartAppFlowy(BuildContext context) async {
    if (UniversalPlatform.isDesktopOrWeb) {
      Navigator.of(context).pop();
    } else {
      await getIt<AuthService>().signOut();
    }
    await runAppFlowy();
  }
}
