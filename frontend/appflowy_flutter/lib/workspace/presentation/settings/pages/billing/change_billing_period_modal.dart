import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';

enum BillingPeriod {
  monthly,
  yearly;

  String get label => switch (this) {
        monthly => LocaleKeys.settings_billingPage_monthlyInterval.tr(),
        yearly => LocaleKeys.settings_billingPage_annualInterval.tr(),
      };

  String get priceInfo => switch (this) {
        monthly => LocaleKeys.settings_billingPage_monthlyPriceInfo.tr(),
        yearly => LocaleKeys.settings_billingPage_annualPriceInfo.tr(),
      };

  RecurringIntervalPB toPB() {
    return switch (this) {
      monthly => RecurringIntervalPB.Month,
      yearly => RecurringIntervalPB.Year,
    };
  }
}

Future<BillingPeriod?> showChangeBillingPeriodModal({
  required BuildContext context,
  required BillingPeriod currentBillingPeriod,
  required Map<BillingPeriod, String> prices,
}) {
  return showDialog<BillingPeriod?>(
    context: context,
    builder: (context) {
      return ChangeBillingPeriodModal(
        billingPeriod: currentBillingPeriod,
        price: prices,
      );
    },
  );
}

class ChangeBillingPeriodModal extends StatefulWidget {
  const ChangeBillingPeriodModal({
    super.key,
    required this.billingPeriod,
    required this.price,
  });

  final BillingPeriod billingPeriod;
  final Map<BillingPeriod, String> price;

  @override
  State<ChangeBillingPeriodModal> createState() =>
      _ChangeBillingPeriodModalState();
}

class _ChangeBillingPeriodModalState extends State<ChangeBillingPeriodModal> {
  late BillingPeriod selectedBillingPeriod = widget.billingPeriod;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return AFModal(
      constraints: BoxConstraints(
        maxWidth: 400,
        maxHeight: 400,
      ),
      child: Column(
        children: [
          AFModalHeader(
            leading: Text(
              LocaleKeys.settings_billingPage_changePeriod.tr(),
              style: theme.textStyle.heading4.prominent(
                color: theme.textColorScheme.primary,
              ),
            ),
            trailing: [
              AFGhostButton.normal(
                onTap: () => Navigator.of(context).pop(),
                padding: EdgeInsets.all(theme.spacing.xs),
                builder: (context, isHovering, disabled) {
                  return Center(
                    child: FlowySvg(
                      FlowySvgs.toast_close_s,
                      size: Size.square(20),
                    ),
                  );
                },
              ),
            ],
          ),
          Expanded(
            child: AFModalBody(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PeriodSelector(
                    price: widget.price[BillingPeriod.monthly]!,
                    interval: BillingPeriod.monthly,
                    isSelected: selectedBillingPeriod == BillingPeriod.monthly,
                    isCurrent: widget.billingPeriod == BillingPeriod.monthly,
                    onSelected: () {
                      setState(
                        () => selectedBillingPeriod = BillingPeriod.monthly,
                      );
                    },
                  ),
                  const VSpace(16),
                  _PeriodSelector(
                    price: widget.price[BillingPeriod.yearly]!,
                    interval: BillingPeriod.yearly,
                    isSelected: selectedBillingPeriod == BillingPeriod.yearly,
                    isCurrent: widget.billingPeriod == BillingPeriod.yearly,
                    onSelected: () {
                      setState(
                        () => selectedBillingPeriod = BillingPeriod.yearly,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          AFModalFooter(
            trailing: [
              AFOutlinedTextButton.normal(
                text: LocaleKeys.button_cancel.tr(),
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
              AFFilledTextButton.primary(
                text: LocaleKeys.button_confirm.tr(),
                disabled: selectedBillingPeriod == widget.billingPeriod,
                onTap: () {
                  Navigator.of(context).pop(
                    selectedBillingPeriod,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.price,
    required this.interval,
    required this.isSelected,
    required this.isCurrent,
    required this.onSelected,
  });

  final String price;
  final BillingPeriod interval;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return GestureDetector(
      onTap: onSelected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? theme.borderColorScheme.themeThick
                  : theme.borderColorScheme.primary,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        FlowyText(
                          interval.label,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        if (isCurrent) ...[
                          const HSpace(8),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              child: FlowyText(
                                LocaleKeys
                                    .settings_billingPage_currentPeriodBadge
                                    .tr(),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const VSpace(8),
                    FlowyText(
                      price,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    const VSpace(4),
                    FlowyText(
                      interval.priceInfo,
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                    ),
                  ],
                ),
                const Spacer(),
                if (isSelected) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: 1.5,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                      ),
                    ),
                    child: SizedBox(
                      height: 22,
                      width: 22,
                      child: Center(
                        child: SizedBox(
                          width: 10,
                          height: 10,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
