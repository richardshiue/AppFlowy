import '../data/models/user_data_location.dart';

sealed class DataLocationState {
  const DataLocationState();
}

class DataLocationLoading extends DataLocationState {
  const DataLocationLoading();
}

class DataLocationReady extends DataLocationState {
  const DataLocationReady({required this.userDataLocation});

  final UserDataLocation userDataLocation;

  DataLocationReady copyWith({UserDataLocation? userDataLocation}) {
    return DataLocationReady(
      userDataLocation: userDataLocation ?? this.userDataLocation,
    );
  }
}

class DataLocationReset extends DataLocationState {
  const DataLocationReset();
}
