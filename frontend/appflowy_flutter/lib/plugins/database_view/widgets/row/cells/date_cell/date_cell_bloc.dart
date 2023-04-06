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

String dateStringFromDateTime(DateTime? dateTime, DateFormat dateFormat) {
  if (dateTime == null) {
    return "";
  }
  intl.DateFormat pattern = intl.DateFormat.yMMMMd('en_US');
  switch (dateFormat) {
    case DateFormat.Friendly:
      break;
    case DateFormat.ISO:
      pattern = intl.DateFormat.yMMMd('en_US');
      break;
    case DateFormat.Local:
      pattern = intl.DateFormat.yMd('en_US');
      break;
    case DateFormat.US:
      pattern = intl.DateFormat.yMMMMEEEEd('en_US');
      break;
  }
  return pattern.format(dateTime);
}

String timeStringFromDateTime(DateTime? dateTime, TimeFormat timeFormat) {
  if (dateTime == null) {
    return "";
  }
  intl.DateFormat pattern = intl.DateFormat.jm('en_US');
  switch (timeFormat) {
    case TimeFormat.TwelveHour:
      break;
    case TimeFormat.TwentyFourHour:
      pattern = intl.DateFormat.Hm('en_US');
      break;
  }
  return pattern.format(dateTime);
}
