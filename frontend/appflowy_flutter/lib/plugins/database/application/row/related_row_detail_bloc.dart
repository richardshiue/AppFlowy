import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-database2/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../database_controller.dart';

import 'row_controller.dart';

part 'related_row_detail_bloc.freezed.dart';

class RelatedRowDetailPageBloc
    extends Bloc<RelatedRowDetailPageEvent, RelatedRowDetailPageState> {
  RelatedRowDetailPageBloc({
    required String databaseId,
    required String initialRowId,
  }) : super(const RelatedRowDetailPageState.loading()) {
    _dispatch();
    _init(databaseId, initialRowId);
  }

  UserProfilePB? _userProfile;
  UserProfilePB? get userProfile => _userProfile;

  @override
  Future<void> close() {
    state.whenOrNull(
      ready: (databaseController, rowController) async {
        await rowController.dispose();
        await databaseController.dispose();
      },
    );
    return super.close();
  }

  void _dispatch() {
    on<RelatedRowDetailPageEvent>((event, emit) async {
      await event.when(
        didInitialize: (databaseController, rowController) async {
          final response = await UserEventGetUserProfile().send();
          response.fold(
            (userProfile) => _userProfile = userProfile,
            (err) => Log.error(err),
          );

          await rowController.initialize();

          await state.maybeWhen(
            ready: (_, oldRowController) async {
              await oldRowController.dispose();
              emit(
                RelatedRowDetailPageState.ready(
                  databaseController: databaseController,
                  rowController: rowController,
                ),
              );
            },
            orElse: () {
              emit(
                RelatedRowDetailPageState.ready(
                  databaseController: databaseController,
                  rowController: rowController,
                ),
              );
            },
          );
        },
      );
    });
  }

  void _init(String databaseId, String initialRowId) async {
    final viewId = await DatabaseEventGetDefaultDatabaseViewId(
      DatabaseIdPB(value: databaseId),
    ).send().fold(
          (pb) => pb.value,
          (error) => null,
        );

    if (viewId == null) {
      return;
    }

    final databaseView = await ViewBackendService.getView(viewId)
        .fold((viewPB) => viewPB, (f) => null);
    if (databaseView == null) {
      return;
    }
    final databaseController = DatabaseController(view: databaseView);
    await databaseController.open().fold(
          (s) => databaseController.setIsLoading(false),
          (f) => null,
        );
    final rowInfo = databaseController.rowCache.getRow(initialRowId);
    if (rowInfo == null) {
      return;
    }
    final rowController = RowController(
      rowMeta: rowInfo.rowMeta,
      viewId: databaseView.id,
      rowCache: databaseController.rowCache,
    );

    add(
      RelatedRowDetailPageEvent.didInitialize(
        databaseController,
        rowController,
      ),
    );
  }
}

@freezed
class RelatedRowDetailPageEvent with _$RelatedRowDetailPageEvent {
  const factory RelatedRowDetailPageEvent.didInitialize(
    DatabaseController databaseController,
    RowController rowController,
  ) = _DidInitialize;
}

@freezed
class RelatedRowDetailPageState with _$RelatedRowDetailPageState {
  const factory RelatedRowDetailPageState.loading() = _LoadingState;
  const factory RelatedRowDetailPageState.ready({
    required DatabaseController databaseController,
    required RowController rowController,
  }) = _ReadyState;
}
