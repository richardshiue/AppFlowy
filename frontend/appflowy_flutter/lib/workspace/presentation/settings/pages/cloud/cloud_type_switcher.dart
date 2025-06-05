import 'package:appflowy/env/cloud_env.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
import 'package:appflowy/mobile/presentation/widgets/flowy_option_tile.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/settings/cloud_setting_bloc.dart';
import 'package:appflowy/workspace/presentation/settings/shared/af_dropdown_menu_entry.dart';
import 'package:appflowy/workspace/presentation/settings/shared/settings_dropdown.dart';
import 'package:appflowy/workspace/presentation/widgets/dialog_v2.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_platform/universal_platform.dart';

class CloudTypeSwitcher extends StatelessWidget {
  const CloudTypeSwitcher({
    super.key,
    required this.cloudType,
    required this.onSelected,
  });

  final AuthenticatorType cloudType;
  final Function(AuthenticatorType) onSelected;

  @override
  Widget build(BuildContext context) {
    final values = integrationMode().isDevelop
        ? AuthenticatorType.values
        : AuthenticatorType.values
            .where((type) => type != AuthenticatorType.appflowyCloudDevelop)
            .toList();

    return UniversalPlatform.isDesktopOrWeb
        ? SettingsDropdown(
            selectedOption: cloudType,
            onChanged: (type) {
              if (type != cloudType) {
                onSelected(type);
                showSimpleAFDialog(
                  context: context,
                  title: LocaleKeys.settings_menu_cloudServerType.tr(),
                  content: LocaleKeys.settings_menu_changeServerTip.tr(),
                  primaryAction: (
                    LocaleKeys.button_ok.tr(),
                    (context) {},
                  ),
                );
              }
            },
            options: values
                .map(
                  (type) => buildDropdownMenuEntry(
                    context,
                    value: type,
                    label: type.i18n,
                  ),
                )
                .toList(),
          )
        : FlowyButton(
            text: FlowyText(
              cloudType.i18n,
            ),
            useIntrinsicWidth: true,
            rightIcon: const Icon(
              Icons.chevron_right,
            ),
            onTap: () => showMobileBottomSheet(
              context,
              showHeader: true,
              showDragHandle: true,
              showDivider: false,
              title: LocaleKeys.settings_menu_cloudServerType.tr(),
              builder: (context) => Column(
                children: values
                    .mapIndexed(
                      (i, e) => FlowyOptionTile.checkbox(
                        text: values[i].i18n,
                        isSelected: cloudType == values[i],
                        onTap: () {
                          onSelected(e);
                          context.pop();
                        },
                        showBottomBorder: i == values.length - 1,
                      ),
                    )
                    .toList(),
              ),
            ),
          );
  }
}

class CloudTypeItem extends StatelessWidget {
  const CloudTypeItem({
    super.key,
    required this.cloudType,
    required this.currentCloudType,
    required this.onSelected,
  });

  final AuthenticatorType cloudType;
  final AuthenticatorType currentCloudType;
  final Function(AuthenticatorType) onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: FlowyButton(
        text: FlowyText.medium(
          cloudType.i18n,
        ),
        rightIcon: currentCloudType == cloudType
            ? const FlowySvg(FlowySvgs.check_s)
            : null,
        onTap: () {
          if (currentCloudType != cloudType) {
            NavigatorAlertDialog(
              title: LocaleKeys.settings_menu_changeServerTip.tr(),
              confirm: () async {
                onSelected(cloudType);
              },
              hideCancelButton: true,
            ).show(context);
          }
          PopoverContainer.of(context).close();
        },
      ),
    );
  }
}

class CloudServerSwitcher extends StatelessWidget {
  const CloudServerSwitcher({
    super.key,
    required this.cloudType,
  });

  final AuthenticatorType cloudType;

  @override
  Widget build(BuildContext context) {
    return UniversalPlatform.isDesktopOrWeb
        ? Row(
            children: [
              Expanded(
                child: FlowyText.medium(
                  LocaleKeys.settings_menu_cloudServerType.tr(),
                ),
              ),
              Flexible(
                child: CloudTypeSwitcher(
                  cloudType: cloudType,
                  onSelected: (type) => context
                      .read<CloudSettingBloc>()
                      .add(CloudSettingEvent.updateCloudType(type)),
                ),
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FlowyText.medium(
                LocaleKeys.settings_menu_cloudServerType.tr(),
              ),
              CloudTypeSwitcher(
                cloudType: cloudType,
                onSelected: (type) => context
                    .read<CloudSettingBloc>()
                    .add(CloudSettingEvent.updateCloudType(type)),
              ),
            ],
          );
  }
}
