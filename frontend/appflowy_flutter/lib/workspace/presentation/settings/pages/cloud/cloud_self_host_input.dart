import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/settings/cloud_setting_bloc.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cloud_server.dart';

class CloudSelfHostInput extends StatefulWidget {
  const CloudSelfHostInput({
    super.key,
    required this.serverUrlTextController,
    required this.webBaseDomainTextController,
  });

  final TextEditingController serverUrlTextController;
  final TextEditingController webBaseDomainTextController;

  @override
  State<CloudSelfHostInput> createState() => _CloudSelfHostInputState();
}

class _CloudSelfHostInputState extends State<CloudSelfHostInput> {
  final serverUrlKey = GlobalKey<AFTextFieldState>();
  final webBaseDomainKey = GlobalKey<AFTextFieldState>();

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return BlocListener<CloudSettingBloc, CloudSettingState>(
      listener: (context, state) {
        if (state is UrlErrorCloudSettingState) {
          final serverUrlError = state.serverUrlError.trim();
          final webBaseDomainError = state.baseWebDomainError.trim();

          if (serverUrlError.isNotEmpty) {
            serverUrlKey.currentState?.syncError(errorText: serverUrlError);
          } else {
            serverUrlKey.currentState?.clearError();
          }

          if (webBaseDomainError.isNotEmpty) {
            webBaseDomainKey.currentState
                ?.syncError(errorText: webBaseDomainError);
          } else {
            webBaseDomainKey.currentState?.clearError();
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppFlowySelfHostTip(),
          VSpace(
            theme.spacing.l,
          ),
          Text(
            LocaleKeys.settings_menu_cloudURL.tr(),
            style: theme.textStyle.caption.standard(
              color: theme.textColorScheme.secondary,
            ),
          ),
          VSpace(
            theme.spacing.xs,
          ),
          AFTextField(
            key: serverUrlKey,
            size: AFTextFieldSize.m,
            controller: widget.serverUrlTextController,
            hintText: LocaleKeys.settings_menu_cloudURLHint.tr(),
            validator: (controller) {
              if (controller.text.trim().isEmpty) {
                return (
                  true,
                  LocaleKeys.settings_menu_appFlowyCloudUrlCanNotBeEmpty.tr(),
                );
              }
              return (false, '');
            },
          ),
          VSpace(
            theme.spacing.l,
          ),
          Text(
            LocaleKeys.settings_menu_webURL.tr(),
            style: theme.textStyle.caption.standard(
              color: theme.textColorScheme.secondary,
            ),
          ),
          VSpace(
            theme.spacing.xs,
          ),
          AFTextField(
            key: webBaseDomainKey,
            size: AFTextFieldSize.m,
            controller: widget.webBaseDomainTextController,
            hintText: LocaleKeys.settings_menu_webURLHint.tr(),
            validator: (controller) {
              if (controller.text.trim().isEmpty) {
                return (
                  true,
                  LocaleKeys.settings_menu_appFlowyCloudUrlCanNotBeEmpty.tr(),
                );
              }
              return (false, '');
            },
          ),
        ],
      ),
    );
  }
}
