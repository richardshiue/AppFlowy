import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-ai/protobuf.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_settings_bloc.freezed.dart';

class ChatSettingsBloc extends Bloc<ChatSettingsEvent, ChatSettingsState> {
  ChatSettingsBloc({required this.chatId})
      : super(ChatSettingsState.initial()) {
    _dispatch();
    _init();
  }

  final String chatId;

  void _dispatch() {
    on<ChatSettingsEvent>(
      (event, emit) {
        event.when(
          didReceiveSelectedSources: (viewIds) {},
          toggleSourceSelection: (viewId) {},
        );
      },
    );
  }

  void _init() {
    AIEventGetChatSettings(ChatId(value: chatId)).send().fold(
      (settings) {
        if (!isClosed) {
          add(
            ChatSettingsEvent.didReceiveSelectedSources(
              selectedViewIds: settings.ragIds,
            ),
          );
        }
      },
      Log.error,
    );
  }
}

@freezed
class ChatSettingsEvent with _$ChatSettingsEvent {
  const factory ChatSettingsEvent.didReceiveSelectedSources({
    required List<String> selectedViewIds,
  }) = _DidReceiveSelectedSources;
  const factory ChatSettingsEvent.toggleSourceSelection({
    required String viewId,
  }) = _ToggleSourceSelection;
}

@freezed
class ChatSettingsState with _$ChatSettingsState {
  factory ChatSettingsState({
    required List<String> selectedViewIds,
  }) = _ChatSettingsState;

  factory ChatSettingsState.initial() => ChatSettingsState(selectedViewIds: []);
}
