import 'dart:async';

import 'package:appflowy/plugins/database_view/application/cell/cell_controller_builder.dart';
import 'package:appflowy/plugins/database_view/application/field/field_controller.dart';
import 'package:appflowy_backend/protobuf/flowy-database/date_type_option_entities.pb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart' as intl;

part 'date_cell_bloc.freezed.dart';

class DateCellBloc extends Bloc<DateCellEvent, DateCellState> {
  final DateCellController cellController;
  void Function()? _onCellChangedFn;

  DateCellBloc({required this.cellController})
      : super(DateCellState.initial(cellController)) {
    on<DateCellEvent>(
      (event, emit) async {
        event.when(
          initial: () => _startListening(),
          didReceiveCellUpdate: (DateCellDataPB? cellData) {
            int timestamp = 0;
            bool includeTime = false;
            if (cellData != null) {
              timestamp = cellData.timestamp.toInt() * 1000;
              includeTime = cellData.includeTime;
            }
            emit(state.copyWith(
              dateTime: DateTime.fromMillisecondsSinceEpoch(timestamp),
              includeTime: includeTime,
            ));
          },
        );
      },
    );
  }

  @override
  Future<void> close() async {
    if (_onCellChangedFn != null) {
      cellController.removeListener(_onCellChangedFn!);
      _onCellChangedFn = null;
    }
    await cellController.dispose();
    return super.close();
  }

  void _startListening() {
    _onCellChangedFn = cellController.startListening(
      onCellChanged: ((data) {
        if (!isClosed) {
          add(DateCellEvent.didReceiveCellUpdate(data));
        }
      }),
    );
  }
}

@freezed
class DateCellEvent with _$DateCellEvent {
  const factory DateCellEvent.initial() = _InitialCell;
  const factory DateCellEvent.didReceiveCellUpdate(DateCellDataPB? data) =
      _DidReceiveCellUpdate;
}

@freezed
class DateCellState with _$DateCellState {
  const factory DateCellState({
    required DateTime? dateTime,
    required bool includeTime,
    required FieldInfo fieldInfo,
  }) = _DateCellState;

  factory DateCellState.initial(DateCellController context) {
    final cellData = context.getCellData();

    if (cellData == null) {
      return DateCellState(
        fieldInfo: context.fieldInfo,
        dateTime: null,
        includeTime: false,
      );
    }

    final timestamp = cellData.timestamp.toInt() * 1000;
    return DateCellState(
      fieldInfo: context.fieldInfo,
      dateTime: DateTime.fromMillisecondsSinceEpoch(timestamp),
      includeTime: cellData.includeTime,
    );
  }
}

String dateStringFromDateTime(DateTime? dateTime) {
  if (dateTime == null) {
    return "";
  }
  return intl.DateFormat.yMMMMd('en_US').format(dateTime);
}

String timeStringFromDateTime(DateTime? dateTime) {
  if (dateTime == null) {
    return "";
  }
  return intl.DateFormat.jm('en_US').format(dateTime);
}
