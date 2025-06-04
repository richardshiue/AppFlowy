import 'package:appflowy_result/appflowy_result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repositories/settings_repository.dart';
import 'data_location_event.dart';
import 'data_location_state.dart';

class DataLocationBloc extends Bloc<DataLocationEvent, DataLocationState> {
  DataLocationBloc({
    required SettingsRepository repository,
  })  : _repository = repository,
        super(DataLocationLoading()) {
    on<DataLocationInitial>(_onInitial);
    on<DataLocationResetToDefault>(_onResetToDefault);
  }

  final SettingsRepository _repository;

  Future<void> _onInitial(
    DataLocationInitial event,
    Emitter<DataLocationState> emit,
  ) async {
    final userDataLocation =
        await _repository.getUserDataLocation().toNullable();

    emit(
      userDataLocation == null
          ? DataLocationLoading()
          : DataLocationReady(userDataLocation: userDataLocation),
    );
  }

  Future<void> _onResetToDefault(
    DataLocationResetToDefault event,
    Emitter<DataLocationState> emit,
  ) async {
    final defaultLocation =
        await _repository.resetUserDataLocation().toNullable();

    if (defaultLocation == null) {
      return;
    }

    emit(
      DataLocationReset(),
    );
    emit(
      DataLocationReady(
        userDataLocation: defaultLocation,
      ),
    );
  }
}
