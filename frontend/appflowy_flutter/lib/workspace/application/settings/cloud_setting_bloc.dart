import 'package:appflowy/env/backend_env.dart';
import 'package:appflowy/env/cloud_env.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/shared/share/constants.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cloud_setting_listener.dart';

class CloudSettingBloc extends Bloc<CloudSettingEvent, CloudSettingState> {
  CloudSettingBloc() : super(LoadingCloudSettingState()) {
    on<InitialCloudSettingEvent>(_onInitialCloudSettingEvent);
    on<UpdateCloudTypeEvent>(_onUpdateCloudTypeEvent);
    on<DidReceiveCloudSettingEvent>(_onDidReceiveCloudSettingEvent);
    on<EnableSyncEvent>(_onEnableSyncEvent);
    on<EnableSyncLogEvent>(_onEnableSyncLogEvent);
    on<UpdateCloudUrlsEvent>(_onUpdateCloudUrlsEvent);
    on<RestartCloudSettingEvent>(_onRestartCloudSettingEvent);
  }

  final UserCloudConfigListener _listener = UserCloudConfigListener();

  @override
  Future<void> close() async {
    await _listener.stop();
    return super.close();
  }

  Future<void> _onInitialCloudSettingEvent(
    InitialCloudSettingEvent event,
    Emitter<CloudSettingState> emit,
  ) async {
    final cloudType = await getAuthenticatorType();
    final workspaceType = await UserEventGetUserProfile().send().fold(
      (profile) => profile.workspaceType,
      (error) {
        Log.error('Error fetching user profile: $error');
        return null;
      },
    );
    if (workspaceType == null) {
      return;
    }
    ReadyCloudSettingState newState = ReadyCloudSettingState(
      cloudType: cloudType,
      workspaceType: workspaceType,
    );

    if (cloudType != AuthenticatorType.local) {
      final cloudSettings = await UserEventGetCloudConfig().send().fold(
        (cloudSettings) => cloudSettings,
        (error) {
          Log.error('Error fetching cloud config: $error');
          return null;
        },
      );

      final config = getIt<AppFlowyCloudSharedEnv>().appflowyCloudConfig;

      final isSyncLogEnabled = await getSyncLogEnabled();

      newState = newState.copyWith(
        customCloudConfig: config,
        isSyncLogEnabled: isSyncLogEnabled,
      );

      _startListening();
    }

    emit(newState);
  }

  Future<void> _onUpdateCloudTypeEvent(
    UpdateCloudTypeEvent event,
    Emitter<CloudSettingState> emit,
  ) async {
    if (state case final ReadyCloudSettingState loadedState) {
      if (loadedState.cloudType != event.newCloudType) {
        emit(
          loadedState.copyWith(
            cloudType: event.newCloudType,
          ),
        );
      }
    }
  }

  Future<void> _onDidReceiveCloudSettingEvent(
    DidReceiveCloudSettingEvent event,
    Emitter<CloudSettingState> emit,
  ) async {
    if (state case final ReadyCloudSettingState loadedState) {
      // emit(
      //   loadedState.copyWith(
      //     isSyncLogEnabled: event.setting.isSyncLogEnabled,
      //   ),
      // );
    }
  }

  Future<void> _onEnableSyncEvent(
    EnableSyncEvent event,
    Emitter<CloudSettingState> emit,
  ) async {
    final config = UpdateCloudConfigPB.create()..enableSync = event.isEnabled;
    await UserEventSetCloudConfig(config).send();
  }

  Future<void> _onEnableSyncLogEvent(
    EnableSyncLogEvent event,
    Emitter<CloudSettingState> emit,
  ) async {
    await setSyncLogEnabled(event.isEnabled);
    if (state case final ReadyCloudSettingState loadedState) {
      emit(loadedState.copyWith(isSyncLogEnabled: event.isEnabled));
    }
  }

  Future<void> _onUpdateCloudUrlsEvent(
    UpdateCloudUrlsEvent event,
    Emitter<CloudSettingState> emit,
  ) async {}

  void _startListening() {
    _listener.start(
      onSettingChanged: (result) {
        if (!isClosed) {
          result.fold(
            (setting) => add(CloudSettingEvent.didReceiveSetting(setting)),
            (error) => Log.error(error),
          );
        }
      },
    );
  }

  Future<void> _onRestartCloudSettingEvent(
    RestartCloudSettingEvent event,
    Emitter<CloudSettingState> emit,
  ) async {
    if (state case final ReadyCloudSettingState readyState) {
      String serverUrlError = '';
      String baseWebDomainError = '';

      switch (readyState.cloudType) {
        case AuthenticatorType.local:
          await useLocalServer();
        case AuthenticatorType.appflowyCloud:
          await useBaseWebDomain(ShareConstants.defaultBaseWebDomain);
          await useAppFlowyBetaCloudWithURL(
            kAppflowyCloudUrl,
            readyState.cloudType,
          );
        case AuthenticatorType.appflowyCloudSelfHost:
          await validateUrl(event.serverUrl).fold(
            (url) => useSelfHostedAppFlowyCloud(url),
            (err) async => serverUrlError = err,
          );
          await validateUrl(event.baseWebDomain).fold(
            (url) => useBaseWebDomain(url),
            (err) async => baseWebDomainError = err,
          );
        case AuthenticatorType.appflowyCloudDevelop:
          await useBaseWebDomain(ShareConstants.defaultBaseWebDomain);
          await useAppFlowyBetaCloudWithURL(kLocalUrl, readyState.cloudType);
      }

      if (serverUrlError.isNotEmpty || baseWebDomainError.isNotEmpty) {
        emit(
          UrlErrorCloudSettingState(
            serverUrlError: serverUrlError,
            baseWebDomainError: baseWebDomainError,
          ),
        );
      } else {
        emit(const RestartCloudSettingState());
      }
    }
  }
}

sealed class CloudSettingEvent {
  const CloudSettingEvent();

  factory CloudSettingEvent.initial() => const InitialCloudSettingEvent();
  factory CloudSettingEvent.updateCloudType(AuthenticatorType newCloudType) =>
      UpdateCloudTypeEvent(newCloudType);
  factory CloudSettingEvent.didReceiveSetting(CloudSettingPB setting) =>
      DidReceiveCloudSettingEvent(setting);
  factory CloudSettingEvent.enableSync(bool isEnabled) =>
      EnableSyncEvent(isEnabled);
  factory CloudSettingEvent.enableSyncLog(bool isEnabled) =>
      EnableSyncLogEvent(isEnabled);
}

class InitialCloudSettingEvent extends CloudSettingEvent {
  const InitialCloudSettingEvent();
}

class UpdateCloudTypeEvent extends CloudSettingEvent {
  const UpdateCloudTypeEvent(this.newCloudType);

  final AuthenticatorType newCloudType;
}

class DidReceiveCloudSettingEvent extends CloudSettingEvent {
  const DidReceiveCloudSettingEvent(this.setting);

  final CloudSettingPB setting;
}

class EnableSyncEvent extends CloudSettingEvent {
  const EnableSyncEvent(this.isEnabled);

  final bool isEnabled;
}

class EnableSyncLogEvent extends CloudSettingEvent {
  const EnableSyncLogEvent(this.isEnabled);

  final bool isEnabled;
}

class UpdateCloudUrlsEvent extends CloudSettingEvent {
  const UpdateCloudUrlsEvent({
    required this.serverUrl,
    required this.baseWebDomain,
  });

  final String serverUrl;
  final String baseWebDomain;
}

class RestartCloudSettingEvent extends CloudSettingEvent {
  const RestartCloudSettingEvent({
    this.serverUrl = '',
    this.baseWebDomain = '',
  });

  final String serverUrl;
  final String baseWebDomain;
}

sealed class CloudSettingState {
  const CloudSettingState();
}

class LoadingCloudSettingState extends CloudSettingState {
  const LoadingCloudSettingState();
}

class ReadyCloudSettingState extends CloudSettingState with EquatableMixin {
  const ReadyCloudSettingState({
    required this.cloudType,
    required this.workspaceType,
    this.customCloudConfig,
    this.isSyncEnabled,
    this.isSyncLogEnabled,
  });

  final AuthenticatorType cloudType;
  final WorkspaceTypePB workspaceType;
  final AppFlowyCloudConfiguration? customCloudConfig;
  final bool? isSyncEnabled;
  final bool? isSyncLogEnabled;

  @override
  List<Object?> get props => [
        cloudType,
        workspaceType,
        customCloudConfig,
        isSyncEnabled,
        isSyncLogEnabled,
      ];

  ReadyCloudSettingState copyWith({
    AuthenticatorType? cloudType,
    WorkspaceTypePB? workspaceType,
    bool? isSyncEnabled,
    bool? isSyncLogEnabled,
    AppFlowyCloudConfiguration? customCloudConfig,
  }) {
    return ReadyCloudSettingState(
      cloudType: cloudType ?? this.cloudType,
      workspaceType: workspaceType ?? this.workspaceType,
      isSyncEnabled: isSyncEnabled ?? this.isSyncEnabled,
      isSyncLogEnabled: isSyncLogEnabled ?? this.isSyncLogEnabled,
      customCloudConfig: customCloudConfig ?? this.customCloudConfig,
    );
  }
}

class UrlErrorCloudSettingState extends CloudSettingState {
  const UrlErrorCloudSettingState({
    this.serverUrlError = '',
    this.baseWebDomainError = '',
  });

  final String serverUrlError;
  final String baseWebDomainError;
}

class RestartCloudSettingState extends CloudSettingState {
  const RestartCloudSettingState();
}

FlowyResult<String, String> validateUrl(String url) {
  try {
    // Use Uri.parse to validate the url.
    final uri = Uri.parse(removeTrailingSlash(url));
    if (uri.isScheme('HTTP') || uri.isScheme('HTTPS')) {
      return FlowyResult.success(uri.toString());
    } else {
      return FlowyResult.failure(
        LocaleKeys.settings_menu_invalidCloudURLScheme.tr(),
      );
    }
  } catch (e) {
    return FlowyResult.failure(e.toString());
  }
}

String removeTrailingSlash(String input) {
  if (input.endsWith('/')) {
    return input.substring(0, input.length - 1);
  }
  return input;
}
