import 'package:appflowy/shared/flowy_error_page.dart';
import 'package:appflowy/shared/loading.dart';
import 'package:appflowy/util/int64_extension.dart';
import 'package:appflowy/workspace/application/settings/appearance/appearance_cubit.dart';
import 'package:appflowy/workspace/application/settings/billing/settings_billing_bloc.dart';
import 'package:appflowy/workspace/application/settings/date_time/date_format_ext.dart';
import 'package:appflowy/workspace/application/settings/plan/settings_plan_bloc.dart';
import 'package:appflowy/workspace/application/settings/plan/workspace_subscription_ext.dart';
import 'package:appflowy/workspace/application/settings/prelude.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/space/shared_widget.dart';
import 'package:appflowy/workspace/presentation/settings/pages/settings_plan_comparison_dialog.dart';
import 'package:appflowy/workspace/presentation/settings/shared/settings_category.dart';
import 'package:appflowy/workspace/presentation/settings/shared/single_setting_action.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_ui/appflowy_ui.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../generated/locale_keys.g.dart';
import '../../shared/settings_body.dart';
import 'change_billing_period_modal.dart';

class SettingsBillingView extends StatefulWidget {
  const SettingsBillingView({
    super.key,
    required this.workspaceId,
    required this.user,
  });

  final String workspaceId;
  final UserProfilePB user;

  @override
  State<SettingsBillingView> createState() => _SettingsBillingViewState();
}

class _SettingsBillingViewState extends State<SettingsBillingView> {
  Loading? loadingIndicator;
  RecurringIntervalPB? selectedInterval;

  @override
  Widget build(BuildContext context) {
    final theme = AppFlowyTheme.of(context);

    return BlocProvider<SettingsBillingBloc>(
      create: (_) => SettingsBillingBloc(
        workspaceId: widget.workspaceId,
        userId: widget.user.id,
      )..add(const SettingsBillingEvent.started()),
      child: BlocConsumer<SettingsBillingBloc, SettingsBillingState>(
        listenWhen: (previous, current) =>
            previous.mapOrNull(ready: (s) => s.isLoading) !=
            current.mapOrNull(ready: (s) => s.isLoading),
        listener: (context, state) {
          if (state.mapOrNull(ready: (s) => s.isLoading) == true) {
            loadingIndicator = Loading(context)..start();
          } else {
            loadingIndicator?.stop();
            loadingIndicator = null;
          }
        },
        builder: (context, state) {
          return state.map(
            initial: (_) => const SizedBox.shrink(),
            loading: (_) => const Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator.adaptive(strokeWidth: 3),
              ),
            ),
            error: (state) {
              if (state.error != null) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: AppFlowyErrorPage(
                      error: state.error!,
                    ),
                  ),
                );
              }

              return ErrorWidget.withDetails(message: 'Something went wrong!');
            },
            ready: (state) {
              final billingPortalEnabled =
                  state.subscriptionInfo.isBillingPortalEnabled;

              final currentBillingPeriod =
                  state.subscriptionInfo.planSubscription.interval ==
                          RecurringIntervalPB.Month
                      ? BillingPeriod.monthly
                      : BillingPeriod.yearly;

              return SettingsBody(
                page: SettingsPage.billing,
                separatorBuilder: () => AFDivider(
                  spacing: theme.spacing.xl,
                ),
                children: [
                  SettingsCategory(
                    title: LocaleKeys.settings_billingPage_plan_title.tr(),
                    children: [
                      SingleSettingAction(
                        onTap: () => _openPricingDialog(
                          context,
                          widget.workspaceId,
                          widget.user.id,
                          state.subscriptionInfo,
                        ),
                        label: state.subscriptionInfo.label,
                        buttonLabel: LocaleKeys
                            .settings_billingPage_plan_planButtonLabel
                            .tr(),
                      ),
                      if (billingPortalEnabled)
                        SingleSettingAction(
                          label: LocaleKeys
                              .settings_billingPage_plan_billingPeriod
                              .tr(),
                          description: currentBillingPeriod.label,
                          buttonLabel: LocaleKeys
                              .settings_billingPage_plan_periodButtonLabel
                              .tr(),
                          onTap: () async {
                            final subscriptionPlan = state.subscriptionInfo
                                .planSubscription.subscriptionPlan;
                            final newInterval =
                                await showChangeBillingPeriodModal(
                              context: context,
                              prices: {
                                BillingPeriod.monthly:
                                    subscriptionPlan.priceMonthBilling,
                                BillingPeriod.yearly:
                                    subscriptionPlan.priceAnnualBilling,
                              },
                              currentBillingPeriod: currentBillingPeriod,
                            );

                            if (context.mounted &&
                                newInterval != null &&
                                newInterval != currentBillingPeriod) {
                              context.read<SettingsBillingBloc>().add(
                                    SettingsBillingEvent.updatePeriod(
                                      plan: state.subscriptionInfo
                                          .planSubscription.subscriptionPlan,
                                      interval: newInterval.toPB(),
                                    ),
                                  );
                            }
                          },
                        ),
                    ],
                  ),
                  if (billingPortalEnabled)
                    SettingsCategory(
                      title: LocaleKeys
                          .settings_billingPage_paymentDetails_title
                          .tr(),
                      children: [
                        SingleSettingAction(
                          onTap: () => context.read<SettingsBillingBloc>().add(
                                const SettingsBillingEvent.openCustomerPortal(),
                              ),
                          label: LocaleKeys
                              .settings_billingPage_paymentDetails_methodLabel
                              .tr(),
                          buttonLabel: LocaleKeys
                              .settings_billingPage_paymentDetails_methodButtonLabel
                              .tr(),
                        ),
                      ],
                    ),
                  SettingsCategory(
                    title: LocaleKeys.settings_billingPage_addons_title.tr(),
                    children: [
                      _AITile(
                        plan: SubscriptionPlanPB.AiMax,
                        label: LocaleKeys
                            .settings_billingPage_addons_aiMax_label
                            .tr(),
                        description: LocaleKeys
                            .settings_billingPage_addons_aiMax_description,
                        activeDescription: LocaleKeys
                            .settings_billingPage_addons_aiMax_activeDescription,
                        canceledDescription: LocaleKeys
                            .settings_billingPage_addons_aiMax_canceledDescription,
                        subscriptionInfo:
                            state.subscriptionInfo.addOns.firstWhereOrNull(
                          (a) => a.type == WorkspaceAddOnPBType.AddOnAiMax,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _openPricingDialog(
    BuildContext context,
    String workspaceId,
    Int64 userId,
    WorkspaceSubscriptionInfoPB subscriptionInfo,
  ) =>
      showDialog<bool?>(
        context: context,
        builder: (_) => BlocProvider<SettingsPlanBloc>(
          create: (_) =>
              SettingsPlanBloc(workspaceId: workspaceId, userId: widget.user.id)
                ..add(const SettingsPlanEvent.started()),
          child: SettingsPlanComparisonDialog(
            workspaceId: workspaceId,
            subscriptionInfo: subscriptionInfo,
          ),
        ),
      ).then((didChangePlan) {
        if (didChangePlan == true && context.mounted) {
          context
              .read<SettingsBillingBloc>()
              .add(const SettingsBillingEvent.started());
        }
      });
}

class _AITile extends StatelessWidget {
  const _AITile({
    required this.label,
    required this.description,
    required this.canceledDescription,
    required this.activeDescription,
    required this.plan,
    this.subscriptionInfo,
  });

  final String label;
  final String description;
  final String canceledDescription;
  final String activeDescription;
  final SubscriptionPlanPB plan;
  final WorkspaceAddOnPB? subscriptionInfo;

  @override
  Widget build(BuildContext context) {
    final isCanceled = subscriptionInfo?.addOnSubscription.status ==
        WorkspaceSubscriptionStatusPB.Canceled;

    final currentBillingPeriod = subscriptionInfo?.addOnSubscription.interval ==
            RecurringIntervalPB.Month
        ? BillingPeriod.monthly
        : BillingPeriod.yearly;

    final dateFormat = context.read<AppearanceSettingsCubit>().state.dateFormat;

    return Column(
      children: [
        SingleSettingAction(
          label: label,
          description: subscriptionInfo != null && isCanceled
              ? canceledDescription.tr(
                  args: [
                    dateFormat.formatDate(
                      subscriptionInfo!.addOnSubscription.endDate.toDateTime(),
                      false,
                    ),
                  ],
                )
              : subscriptionInfo != null
                  ? activeDescription.tr(
                      args: [
                        dateFormat.formatDate(
                          subscriptionInfo!.addOnSubscription.endDate
                              .toDateTime(),
                          false,
                        ),
                      ],
                    )
                  : description.tr(),
          buttonLabel: subscriptionInfo != null
              ? isCanceled
                  ? LocaleKeys.settings_billingPage_addons_renewLabel.tr()
                  : LocaleKeys.settings_billingPage_addons_removeLabel.tr()
              : LocaleKeys.settings_billingPage_addons_addLabel.tr(),
          onTap: () async {
            if (subscriptionInfo != null) {
              await showConfirmDialog(
                context: context,
                style: ConfirmPopupStyle.cancelAndOk,
                title: LocaleKeys.settings_billingPage_addons_removeDialog_title
                    .tr(args: [plan.label]).tr(),
                description: LocaleKeys
                    .settings_billingPage_addons_removeDialog_description
                    .tr(namedArgs: {"plan": plan.label.tr()}),
                confirmLabel: LocaleKeys.button_confirm.tr(),
                onConfirm: (_) => context
                    .read<SettingsBillingBloc>()
                    .add(SettingsBillingEvent.cancelSubscription(plan)),
              );
            } else {
              // Add the addon
              context
                  .read<SettingsBillingBloc>()
                  .add(SettingsBillingEvent.addSubscription(plan));
            }
          },
        ),
        if (subscriptionInfo != null) ...[
          const VSpace(10),
          SingleSettingAction(
            label: LocaleKeys.settings_billingPage_planPeriod.tr(
              args: [
                subscriptionInfo!.addOnSubscription.subscriptionPlan.label,
              ],
            ),
            description: subscriptionInfo!.addOnSubscription.interval.label,
            buttonLabel:
                LocaleKeys.settings_billingPage_plan_periodButtonLabel.tr(),
            onTap: () async {
              final subscriptionPlan =
                  subscriptionInfo!.addOnSubscription.subscriptionPlan;

              final newInterval = await showChangeBillingPeriodModal(
                context: context,
                prices: {
                  BillingPeriod.monthly: subscriptionPlan.priceMonthBilling,
                  BillingPeriod.yearly: subscriptionPlan.priceAnnualBilling,
                },
                currentBillingPeriod: currentBillingPeriod,
              );

              if (context.mounted &&
                  newInterval != null &&
                  newInterval != currentBillingPeriod) {
                context.read<SettingsBillingBloc>().add(
                      SettingsBillingEvent.updatePeriod(
                        plan: subscriptionInfo!
                            .addOnSubscription.subscriptionPlan,
                        interval: newInterval.toPB(),
                      ),
                    );
              }
            },
          ),
        ],
      ],
    );
  }
}
