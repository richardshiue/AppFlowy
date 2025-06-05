import 'package:appflowy/workspace/application/settings/prelude.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:flutter/material.dart';

import 'package:appflowy/shared/feature_flags.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';

import '../../shared/settings_body.dart';

class FeatureFlagsPage extends StatelessWidget {
  const FeatureFlagsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsBody(
      page: SettingsPage.featureFlags,
      children: [
        SeparatedColumn(
          separatorBuilder: () => AFDivider(),
          children: FeatureFlag.data.entries
              .where((e) => e.key != FeatureFlag.unknown)
              .map((e) => _FeatureFlagItem(featureFlag: e.key))
              .toList(),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: AFFilledTextButton.primary(
            text: 'Restart the app to apply changes',
            onTap: () {
              runAppFlowy();
              Navigator.of(context).pop();
            },
          ),
        ),
      ],
    );
  }
}

class _FeatureFlagItem extends StatefulWidget {
  const _FeatureFlagItem({required this.featureFlag});

  final FeatureFlag featureFlag;

  @override
  State<_FeatureFlagItem> createState() => _FeatureFlagItemState();
}

class _FeatureFlagItemState extends State<_FeatureFlagItem> {
  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return ListTile(
      title: Text(
        widget.featureFlag.name,
        style: theme.textStyle.body.standard(
          color: theme.textColorScheme.primary,
        ),
      ),
      subtitle: Text(
        widget.featureFlag.description,
        style: theme.textStyle.caption.standard(
          color: theme.textColorScheme.secondary,
        ),
      ),
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 0.0,
      trailing: Switch.adaptive(
        value: widget.featureFlag.isOn,
        onChanged: (value) async {
          await widget.featureFlag.update(value);
          setState(() {});
        },
      ),
    );
  }
}
