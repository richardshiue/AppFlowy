import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/settings/ai/settings_ai_bloc.dart';
import 'package:appflowy/workspace/application/settings/prelude.dart';
import 'package:appflowy/workspace/presentation/settings/pages/ai/local_ai_setting.dart';
import 'package:appflowy/workspace/presentation/settings/pages/ai/model_selection.dart';
import 'package:appflowy/workspace/presentation/widgets/toggle/toggle.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/setting_list_tile.dart';
import '../../shared/settings_body.dart';

class SettingsAIView extends StatelessWidget {
  const SettingsAIView({
    super.key,
    required this.userProfile,
    required this.currentWorkspaceMemberRole,
    required this.workspaceId,
  });

  final UserProfilePB userProfile;
  final AFRolePB? currentWorkspaceMemberRole;
  final String workspaceId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SettingsAIBloc>(
      create: (_) => SettingsAIBloc(userProfile, workspaceId)
        ..add(const SettingsAIEvent.started()),
      child: SettingsBody(
        page: SettingsPage.ai,
        separatorBuilder: () => AFDivider(
          spacing: AppFlowyTheme.of(context).spacing.xl,
        ),
        children: [
          const AIModelSelection(),
          const _AISearchToggle(),
          const LocalAISetting(),
        ],
      ),
    );
  }
}

class _AISearchToggle extends StatelessWidget {
  const _AISearchToggle();

  @override
  Widget build(BuildContext context) {
    return SettingListTile(
      label: LocaleKeys.settings_aiPage_keys_enableAISearchTitle.tr(),
      trailing: [
        BlocBuilder<SettingsAIBloc, SettingsAIState>(
          builder: (context, state) {
            if (state.aiSettings == null) {
              return const Padding(
                padding: EdgeInsets.only(top: 6),
                child: SizedBox(
                  height: 26,
                  width: 26,
                  child: CircularProgressIndicator.adaptive(),
                ),
              );
            } else {
              return Toggle(
                value: state.enableSearchIndexing,
                onChanged: (_) => context
                    .read<SettingsAIBloc>()
                    .add(const SettingsAIEvent.toggleAISearch()),
              );
            }
          },
        ),
      ],
    );
  }
}
