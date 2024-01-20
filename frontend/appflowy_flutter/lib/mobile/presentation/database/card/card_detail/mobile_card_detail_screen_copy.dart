// ignore_for_file: unused_import

import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/mobile/presentation/bottom_sheet/bottom_sheet.dart';
import 'package:appflowy/mobile/presentation/widgets/flowy_mobile_quick_action_button.dart';
import 'package:appflowy/plugins/database/application/database_controller.dart';
import 'package:appflowy/plugins/database/application/field/field_controller.dart';
import 'package:appflowy/plugins/database/application/row/row_cache.dart';
import 'package:appflowy/plugins/database/application/row/row_service.dart';
import 'package:appflowy/plugins/database/grid/application/row/mobile_row_detail_bloc.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/row_entities.pb.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';

import 'mobile_card_detail_screen.dart';
import 'widgets/mobile_create_field_button.dart';
import 'widgets/mobile_row_property_list.dart';

class MobileRowDetailPage2 extends StatefulWidget {
  const MobileRowDetailPage2({
    super.key,
    required this.databaseController,
    required this.rowId,
  });

  static const routeName = '/MobileRowDetailPages';
  static const argDatabaseController = 'databaseController';
  static const argRowId = 'rowId';

  final DatabaseController databaseController;
  final String rowId;

  @override
  State<MobileRowDetailPage2> createState() => _MobileRowDetailPage2State();
}

class _MobileRowDetailPage2State extends State<MobileRowDetailPage2> {
  late final MobileRowDetailBloc _bloc;
  late final PageController _pageController;

  String get viewId => widget.databaseController.viewId;
  RowCache get rowCache => widget.databaseController.rowCache;
  FieldController get fieldController =>
      widget.databaseController.fieldController;

  @override
  void initState() {
    super.initState();
    _bloc = MobileRowDetailBloc(
      databaseController: widget.databaseController,
    )..add(MobileRowDetailEvent.initial(widget.rowId));
    final initialPage = rowCache.rowInfos
        .indexWhere((rowInfo) => rowInfo.rowId == widget.rowId);
    _pageController = PageController(
      initialPage: initialPage == -1 ? 0 : initialPage,
      viewportFraction: 0.9,
    );
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: null,
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: BlocBuilder<MobileRowDetailBloc, MobileRowDetailState>(
            buildWhen: (previous, current) =>
                previous.rowInfos.length != current.rowInfos.length,
            builder: (context, state) {
              if (state.isLoading) {
                return const SizedBox.shrink();
              }
              return Hero(
                tag: 'rawr',
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (page) {
                    final rowId = _bloc.state.rowInfos[page].rowId;
                    _bloc.add(MobileRowDetailEvent.changeRowId(rowId));
                  },
                  itemCount: state.rowInfos.length,
                  itemBuilder: (context, index) {
                    if (state.rowInfos.isEmpty || state.currentRowId == null) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Material(
                        borderRadius: BorderRadius.circular(32),
                        color: Colors.white,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            context.push(
                              MobileRowDetailPage.routeName,
                              extra: {
                                MobileRowDetailPage.argRowId: widget.rowId,
                                MobileRowDetailPage.argDatabaseController:
                                    widget.databaseController,
                              },
                            );
                          },
                          child: MobileRowDetailPageContent(
                            databaseController: widget.databaseController,
                            rowMeta: state.rowInfos[index].rowMeta,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.close),
      ),
      actions: [
        IconButton(
          iconSize: 40,
          icon: const FlowySvg(
            FlowySvgs.details_horizontal_s,
            size: Size.square(20),
          ),
          padding: EdgeInsets.zero,
          onPressed: () => _showCardActions(context),
        ),
      ],
    );
  }

  void _showCardActions(BuildContext context) {
    showMobileBottomSheet(
      context,
      backgroundColor: Theme.of(context).colorScheme.background,
      padding: const EdgeInsets.only(top: 8, bottom: 38),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: MobileQuickActionButton(
              onTap: () {
                final rowId = _bloc.state.currentRowId;
                if (rowId == null) {
                  return;
                }
                RowBackendService.duplicateRow(viewId, rowId);
                context
                  ..pop()
                  ..pop();
                Fluttertoast.showToast(
                  msg: LocaleKeys.board_cardDuplicated.tr(),
                  gravity: ToastGravity.BOTTOM,
                );
              },
              icon: FlowySvgs.copy_s,
              text: LocaleKeys.button_duplicate.tr(),
            ),
          ),
          const Divider(height: 9),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: MobileQuickActionButton(
              onTap: () {
                final rowId = _bloc.state.currentRowId;
                if (rowId == null) {
                  return;
                }
                RowBackendService.deleteRow(viewId, rowId);
                context
                  ..pop()
                  ..pop();
                Fluttertoast.showToast(
                  msg: LocaleKeys.board_cardDeleted.tr(),
                  gravity: ToastGravity.BOTTOM,
                );
              },
              icon: FlowySvgs.m_delete_m,
              text: LocaleKeys.button_delete.tr(),
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const Divider(height: 9),
        ],
      ),
    );
  }
}
