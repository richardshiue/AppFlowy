import 'dart:async';

import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/database_view/application/cell/cell_controller_builder.dart';
import 'package:appflowy/plugins/database_view/application/cell/cell_service.dart';
import 'package:appflowy/plugins/database_view/application/field/field_service.dart';
import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart'
    show StringTranslateExtension;
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/code.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-database/date_type_option.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-database/date_type_option_entities.pb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart' as intl;
import 'package:table_calendar/table_calendar.dart';
import 'package:protobuf/protobuf.dart';

part 'date_cal_bloc.freezed.dart';

class DateCellCalendarBloc
    extends Bloc<DateCellCalendarEvent, DateCellCalendarState> {
  final DateCellController cellController;
  void Function()? _onCellChangedFn;

  DateCellCalendarBloc({
    required DateTypeOptionPB dateTypeOptionPB,
    required DateCellDataPB? cellData,
    required this.cellController,
  }) : super(DateCellCalendarState.initial(dateTypeOptionPB, cellData)) {
    on<DateCellCalendarEvent>(
      (event, emit) async {
        await event.when(
          initial: () async => _startListening(),
          didReceiveCellUpdate: (DateCellDataPB? cellData) {
            DateTime? dateTime = state.dateTime;
            bool includeTime = state.includeTime;
            if (cellData != null) {
              final timestamp = cellData.timestamp.toInt() * 1000;
              dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
              includeTime = cellData.includeTime;
            }
            emit(state.copyWith(
              dateTime: dateTime,
              includeTime: includeTime,
            ));
          },
          didReceiveTimeFormatError: (String? timeFormatError) {
            emit(state.copyWith(timeFormatError: timeFormatError));
          },
          setCalFormat: (CalendarFormat format) {
            emit(state.copyWith(format: format));
          },
          setFocusedDay: (DateTime focusedDay) {
            emit(state.copyWith(focusedDay: focusedDay));
          },
          selectDay: (DateTime date) async {
            await _updateDateData(emit, date: date);
          },
          setIncludeTime: (bool includeTime) async {
            await _updateDateData(emit, includeTime: includeTime);
          },
          setTime: (String time) async {
            await _updateDateData(emit, time: time);
          },
          setDateFormat: (DateFormat dateFormat) async {
            await _updateTypeOption(emit, dateFormat: dateFormat);
          },
          setTimeFormat: (TimeFormat timeFormat) async {
            await _updateTypeOption(emit, timeFormat: timeFormat);
          },
        );
      },
    );
  }

  Either<DateTime, String> _parseTimeString(String timeString) {
    Either<DateTime, String> result;

    intl.DateFormat format = intl.DateFormat.jm('en_US');
    switch (state.dateTypeOptionPB.timeFormat) {
      case TimeFormat.TwelveHour:
        format = intl.DateFormat.jm('en_US');
        break;
      case TimeFormat.TwentyFourHour:
        format = intl.DateFormat.Hm('en_US');
        break;
    }
    try {
      DateTime time = format.parseLoose(timeString);
      result = left(time);
    } on FormatException catch (_) {
      result = right(timeFormatPrompt());
    }

    return result;
  }

  Future<void> _updateDateData(Emitter<DateCellCalendarState> emit,
      {DateTime? date, String? time, bool? includeTime}) {
    DateTime? newDateTime;
    bool newIncludeTime = state.includeTime;

    if (date != null) {
      newDateTime = date;
      if (state.dateTime != null) {
        final hours = state.dateTime!.hour;
        final minutes = state.dateTime!.minute;
        newDateTime = DateTime(
          newDateTime.year,
          newDateTime.month,
          newDateTime.day,
          hours,
          minutes,
        );
      }
    }

    if (time != null) {
      final parseResults = _parseTimeString(time);
      newDateTime = parseResults.fold(
        (time) {
          if (state.dateTime == null) {
            final now = DateTime.now();
            return DateTime(
              now.year,
              now.month,
              now.day,
              time.hour,
              time.minute,
            );
          } else {
            return DateTime(
              state.dateTime!.year,
              state.dateTime!.month,
              state.dateTime!.day,
              time.hour,
              time.minute,
            );
          }
        },
        (err) {
          add(DateCellCalendarEvent.didReceiveTimeFormatError(err));
          return state.dateTime;
        },
      );
    }

    if (includeTime != null) {
      newIncludeTime = includeTime;
    }

    return _saveDateData(emit, newDateTime, newIncludeTime);
  }

  Future<void> _saveDateData(
    Emitter<DateCellCalendarState> emit,
    DateTime? dateTime,
    bool includeTime,
  ) async {
    cellController.saveCellData(DateCellData(
        dateTime: dateTime ?? state.dateTime, includeTime: includeTime));
  }

  String timeFormatPrompt() {
    String msg = "${LocaleKeys.grid_field_invalidTimeFormat.tr()}.";
    switch (state.dateTypeOptionPB.timeFormat) {
      case TimeFormat.TwelveHour:
        msg = "$msg e.g. 01:00 PM";
        break;
      case TimeFormat.TwentyFourHour:
        msg = "$msg e.g. 13:00";
        break;
      default:
        break;
    }
    return msg;
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
      onCellChanged: ((cell) {
        if (!isClosed) {
          add(DateCellCalendarEvent.didReceiveCellUpdate(cell));
        }
      }),
    );
  }

  Future<void>? _updateTypeOption(
    Emitter<DateCellCalendarState> emit, {
    DateFormat? dateFormat,
    TimeFormat? timeFormat,
  }) async {
    state.dateTypeOptionPB.freeze();
    final newDateTypeOption = state.dateTypeOptionPB.rebuild((typeOption) {
      if (dateFormat != null) {
        typeOption.dateFormat = dateFormat;
      }

      if (timeFormat != null) {
        typeOption.timeFormat = timeFormat;
      }
    });

    final result = await FieldBackendService.updateFieldTypeOption(
      viewId: cellController.viewId,
      fieldId: cellController.fieldInfo.id,
      typeOptionData: newDateTypeOption.writeToBuffer(),
    );

    result.fold(
      (l) => emit(state.copyWith(
          dateTypeOptionPB: newDateTypeOption,
          timeHintText: _timeHintText(newDateTypeOption))),
      (err) => Log.error(err),
    );
  }
}

@freezed
class DateCellCalendarEvent with _$DateCellCalendarEvent {
  // initial event
  const factory DateCellCalendarEvent.initial() = _Initial;

  // cell is updated in the backend, need to update the UI
  const factory DateCellCalendarEvent.didReceiveCellUpdate(
      DateCellDataPB? data) = _DidReceiveCellUpdate;
  const factory DateCellCalendarEvent.didReceiveTimeFormatError(
      String? timeFormatError) = _DidUpdateCalData;

  // table calendar's UI setting is changed in the frontend
  const factory DateCellCalendarEvent.setCalFormat(CalendarFormat format) =
      _CalendarFormat;
  const factory DateCellCalendarEvent.setFocusedDay(DateTime day) = _FocusedDay;

  // date cell data is modified, need to save to the backend
  const factory DateCellCalendarEvent.selectDay(DateTime day) = _SelectDay;
  const factory DateCellCalendarEvent.setTime(String time) = _Time;
  const factory DateCellCalendarEvent.setIncludeTime(bool includeTime) =
      _IncludeTime;

  // date field type option is modified, need to save to the backend
  const factory DateCellCalendarEvent.setDateFormat(DateFormat dateFormat) =
      _DateFormat;
  const factory DateCellCalendarEvent.setTimeFormat(TimeFormat timeFormat) =
      _TimeFormat;
}

@freezed
class DateCellCalendarState with _$DateCellCalendarState {
  const factory DateCellCalendarState({
    required DateTypeOptionPB dateTypeOptionPB,
    required CalendarFormat format,
    required DateTime focusedDay,
    required String? timeFormatError,
    required DateTime? dateTime,
    required bool includeTime,
    required String timeHintText,
  }) = _DateCellCalendarState;

  factory DateCellCalendarState.initial(
    DateTypeOptionPB dateTypeOptionPB,
    DateCellDataPB? cellData,
  ) {
    DateTime? dateTime;
    bool includeTime = false;
    if (cellData != null) {
      final timestamp = cellData.timestamp.toInt() * 1000;
      dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      includeTime = cellData.includeTime;
    }
    return DateCellCalendarState(
      dateTypeOptionPB: dateTypeOptionPB,
      format: CalendarFormat.month,
      focusedDay: DateTime.now(),
      dateTime: dateTime,
      includeTime: includeTime,
      timeFormatError: null,
      timeHintText: _timeHintText(dateTypeOptionPB),
    );
  }
}

String _timeHintText(DateTypeOptionPB typeOption) {
  switch (typeOption.timeFormat) {
    case TimeFormat.TwelveHour:
      return LocaleKeys.document_date_timeHintTextInTwelveHour.tr();
    case TimeFormat.TwentyFourHour:
      return LocaleKeys.document_date_timeHintTextInTwentyFourHour.tr();
    default:
      return "";
  }
}
