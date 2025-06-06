import 'dart:async';

import 'package:appflowy/plugins/trash/application/trash_listener.dart';
import 'package:appflowy/plugins/trash/application/trash_service.dart';
import 'package:appflowy/workspace/application/command_palette/search_service.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:appflowy_backend/protobuf/flowy-search/result.pb.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'command_palette_bloc.freezed.dart';

class Debouncer {
  Debouncer({required this.delay});

  final Duration delay;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

class CommandPaletteBloc
    extends Bloc<CommandPaletteEvent, CommandPaletteState> {
  CommandPaletteBloc() : super(CommandPaletteState.initial()) {
    on<_SearchChanged>(_onSearchChanged);
    on<_PerformSearch>(_onPerformSearch);
    on<_NewSearchStream>(_onNewSearchStream);
    on<_ResultsChanged>(_onResultsChanged);
    on<_TrashChanged>(_onTrashChanged);
    on<_WorkspaceChanged>(_onWorkspaceChanged);
    on<_ClearSearch>(_onClearSearch);
    on<_GoingToAskAI>(_onGoingToAskAI);
    on<_AskedAI>(_onAskedAI);
    on<_RefreshCachedViews>(_onRefreshCachedViews);
    on<_UpdateCachedViews>(_onUpdateCachedViews);

    _initTrash();
    _refreshCachedViews();
  }

  final Debouncer _searchDebouncer = Debouncer(
    delay: const Duration(milliseconds: 300),
  );
  final TrashService _trashService = TrashService();
  final TrashListener _trashListener = TrashListener();
  String? _activeQuery;

  @override
  Future<void> close() {
    _trashListener.close();
    _searchDebouncer.dispose();
    state.searchResponseStream?.dispose();
    return super.close();
  }

  Future<void> _initTrash() async {
    _trashListener.start(
      trashUpdated: (trashOrFailed) => add(
        CommandPaletteEvent.trashChanged(
          trash: trashOrFailed.toNullable(),
        ),
      ),
    );

    final trashOrFailure = await _trashService.readTrash();
    trashOrFailure.fold(
      (trash) {
        if (!isClosed) {
          add(CommandPaletteEvent.trashChanged(trash: trash.items));
        }
      },
      (error) => debugPrint('Failed to load trash: $error'),
    );
  }

  Future<void> _refreshCachedViews() async {
    /// Sometimes non-existent views appear in the search results
    /// and the icon data for the search results is empty
    /// Fetching all views can temporarily resolve these issues
    final repeatedViewPB =
        (await ViewBackendService.getAllViews()).toNullable();
    if (repeatedViewPB == null || isClosed) return;
    add(CommandPaletteEvent.updateCachedViews(views: repeatedViewPB.items));
  }

  FutureOr<void> _onRefreshCachedViews(
    _RefreshCachedViews event,
    Emitter<CommandPaletteState> emit,
  ) {
    _refreshCachedViews();
  }

  FutureOr<void> _onUpdateCachedViews(
    _UpdateCachedViews event,
    Emitter<CommandPaletteState> emit,
  ) {
    final cachedViews = <String, ViewPB>{};
    for (final view in event.views) {
      cachedViews[view.id] = view;
    }
    emit(state.copyWith(cachedViews: cachedViews));
  }

  FutureOr<void> _onSearchChanged(
    _SearchChanged event,
    Emitter<CommandPaletteState> emit,
  ) {
    _searchDebouncer.run(
      () {
        if (!isClosed) {
          add(CommandPaletteEvent.performSearch(search: event.search));
        }
      },
    );
  }

  FutureOr<void> _onPerformSearch(
    _PerformSearch event,
    Emitter<CommandPaletteState> emit,
  ) async {
    if (event.search.isEmpty) {
      emit(
        state.copyWith(
          query: null,
          searching: false,
          serverResponseItems: [],
          localResponseItems: [],
          combinedResponseItems: {},
          resultSummaries: [],
          generatingAIOverview: false,
        ),
      );
    } else {
      emit(state.copyWith(query: event.search, searching: true));
      _activeQuery = event.search;

      unawaited(
        SearchBackendService.performSearch(
          event.search,
        ).then(
          (result) => result.fold(
            (stream) {
              if (!isClosed && _activeQuery == event.search) {
                add(CommandPaletteEvent.newSearchStream(stream: stream));
              }
            },
            (error) {
              debugPrint('Search error: $error');
              if (!isClosed) {
                add(
                  CommandPaletteEvent.resultsChanged(
                    searchId: '',
                    searching: false,
                    generatingAIOverview: false,
                  ),
                );
              }
            },
          ),
        ),
      );
    }
  }

  FutureOr<void> _onNewSearchStream(
    _NewSearchStream event,
    Emitter<CommandPaletteState> emit,
  ) {
    state.searchResponseStream?.dispose();
    emit(
      state.copyWith(
        searchId: event.stream.searchId,
        searchResponseStream: event.stream,
      ),
    );

    event.stream.listen(
      onLocalItems: (items, searchId) => _handleResultsUpdate(
        searchId: searchId,
        localItems: items,
      ),
      onServerItems: (items, searchId, searching, generatingAIOverview) =>
          _handleResultsUpdate(
        searchId: searchId,
        summaries: [], // when got server search result, summaries should be empty
        serverItems: items,
        searching: searching,
        generatingAIOverview: generatingAIOverview,
      ),
      onSummaries: (summaries, searchId, searching, generatingAIOverview) =>
          _handleResultsUpdate(
        searchId: searchId,
        summaries: summaries,
        searching: searching,
        generatingAIOverview: generatingAIOverview,
      ),
      onFinished: (searchId) => _handleResultsUpdate(
        searchId: searchId,
        searching: false,
      ),
    );
  }

  void _handleResultsUpdate({
    required String searchId,
    List<SearchResponseItemPB>? serverItems,
    List<LocalSearchResponseItemPB>? localItems,
    List<SearchSummaryPB>? summaries,
    bool searching = true,
    bool generatingAIOverview = false,
  }) {
    if (_isActiveSearch(searchId)) {
      add(
        CommandPaletteEvent.resultsChanged(
          searchId: searchId,
          serverItems: serverItems,
          localItems: localItems,
          summaries: summaries,
          searching: searching,
          generatingAIOverview: generatingAIOverview,
        ),
      );
    }
  }

  FutureOr<void> _onResultsChanged(
    _ResultsChanged event,
    Emitter<CommandPaletteState> emit,
  ) async {
    if (state.searchId != event.searchId) return;

    final combinedItems = <String, SearchResultItem>{};
    for (final item in event.serverItems ?? state.serverResponseItems) {
      combinedItems[item.id] = SearchResultItem(
        id: item.id,
        icon: item.icon,
        displayName: item.displayName,
        content: item.content,
        workspaceId: item.workspaceId,
      );
    }

    for (final item in event.localItems ?? state.localResponseItems) {
      combinedItems.putIfAbsent(
        item.id,
        () => SearchResultItem(
          id: item.id,
          icon: item.icon,
          displayName: item.displayName,
          content: '',
          workspaceId: item.workspaceId,
        ),
      );
    }

    emit(
      state.copyWith(
        serverResponseItems: event.serverItems ?? state.serverResponseItems,
        localResponseItems: event.localItems ?? state.localResponseItems,
        resultSummaries: event.summaries ?? state.resultSummaries,
        combinedResponseItems: combinedItems,
        searching: event.searching,
        generatingAIOverview: event.generatingAIOverview,
      ),
    );
  }

  FutureOr<void> _onTrashChanged(
    _TrashChanged event,
    Emitter<CommandPaletteState> emit,
  ) async {
    if (event.trash != null) {
      emit(state.copyWith(trash: event.trash!));
    } else {
      final trashOrFailure = await _trashService.readTrash();
      trashOrFailure.fold((trash) {
        emit(state.copyWith(trash: trash.items));
      }, (error) {
        // Optionally handle error; otherwise, we simply do nothing.
      });
    }
  }

  FutureOr<void> _onWorkspaceChanged(
    _WorkspaceChanged event,
    Emitter<CommandPaletteState> emit,
  ) {
    emit(
      state.copyWith(
        query: '',
        serverResponseItems: [],
        localResponseItems: [],
        combinedResponseItems: {},
        resultSummaries: [],
        searching: false,
        generatingAIOverview: false,
      ),
    );
    _refreshCachedViews();
  }

  FutureOr<void> _onClearSearch(
    _ClearSearch event,
    Emitter<CommandPaletteState> emit,
  ) {
    emit(CommandPaletteState.initial().copyWith(trash: state.trash));
  }

  FutureOr<void> _onGoingToAskAI(
    _GoingToAskAI event,
    Emitter<CommandPaletteState> emit,
  ) {
    emit(state.copyWith(askAI: true, askAISources: event.sources));
  }

  FutureOr<void> _onAskedAI(
    _AskedAI event,
    Emitter<CommandPaletteState> emit,
  ) {
    emit(state.copyWith(askAI: false, askAISources: null));
  }

  bool _isActiveSearch(String searchId) =>
      !isClosed && state.searchId == searchId;
}

@freezed
class CommandPaletteEvent with _$CommandPaletteEvent {
  const factory CommandPaletteEvent.searchChanged({required String search}) =
      _SearchChanged;
  const factory CommandPaletteEvent.performSearch({required String search}) =
      _PerformSearch;
  const factory CommandPaletteEvent.newSearchStream({
    required SearchResponseStream stream,
  }) = _NewSearchStream;
  const factory CommandPaletteEvent.resultsChanged({
    required String searchId,
    required bool searching,
    required bool generatingAIOverview,
    List<SearchResponseItemPB>? serverItems,
    List<LocalSearchResponseItemPB>? localItems,
    List<SearchSummaryPB>? summaries,
  }) = _ResultsChanged;

  const factory CommandPaletteEvent.trashChanged({
    @Default(null) List<TrashPB>? trash,
  }) = _TrashChanged;
  const factory CommandPaletteEvent.workspaceChanged({
    @Default(null) String? workspaceId,
  }) = _WorkspaceChanged;
  const factory CommandPaletteEvent.clearSearch() = _ClearSearch;
  const factory CommandPaletteEvent.goingToAskAI({
    @Default(null) List<SearchSourcePB>? sources,
  }) = _GoingToAskAI;
  const factory CommandPaletteEvent.askedAI() = _AskedAI;
  const factory CommandPaletteEvent.refreshCachedViews() = _RefreshCachedViews;
  const factory CommandPaletteEvent.updateCachedViews({
    required List<ViewPB> views,
  }) = _UpdateCachedViews;
}

class SearchResultItem {
  const SearchResultItem({
    required this.id,
    required this.icon,
    required this.content,
    required this.displayName,
    this.workspaceId,
  });

  final String id;
  final String content;
  final ResultIconPB icon;
  final String displayName;
  final String? workspaceId;
}

@freezed
class CommandPaletteState with _$CommandPaletteState {
  const CommandPaletteState._();
  const factory CommandPaletteState({
    @Default(null) String? query,
    @Default([]) List<SearchResponseItemPB> serverResponseItems,
    @Default([]) List<LocalSearchResponseItemPB> localResponseItems,
    @Default({}) Map<String, SearchResultItem> combinedResponseItems,
    @Default({}) Map<String, ViewPB> cachedViews,
    @Default([]) List<SearchSummaryPB> resultSummaries,
    @Default(null) SearchResponseStream? searchResponseStream,
    required bool searching,
    required bool generatingAIOverview,
    @Default(false) bool askAI,
    @Default(null) List<SearchSourcePB>? askAISources,
    @Default([]) List<TrashPB> trash,
    @Default(null) String? searchId,
  }) = _CommandPaletteState;

  factory CommandPaletteState.initial() => const CommandPaletteState(
        searching: false,
        generatingAIOverview: false,
      );
}
