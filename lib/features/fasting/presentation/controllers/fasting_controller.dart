import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/notifications/notifications_service.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/ui_message.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/fasting_repository.dart';
import '../../domain/fasting_engine.dart';
import '../../domain/fasting_protocol.dart';
import '../../domain/fasting_session.dart';
import '../../domain/fasting_status.dart';
import '../fasting_strings.dart';

class FastingUiState extends Equatable {
  const FastingUiState({
    required this.isLoading,
    required this.protocols,
    required this.status,
    this.selectedProtocol,
    this.session,
    this.screenError,
    this.uiMessage,
  });

  final bool isLoading;
  final List<FastingProtocol> protocols;
  final FastingProtocol? selectedProtocol;
  final FastingSession? session;
  final FastingStatus status;
  final String? screenError;
  final UiMessage? uiMessage;

  factory FastingUiState.initial() {
    return FastingUiState(
      isLoading: true,
      protocols: const [],
      status: FastingStatus.inactive(),
    );
  }

  bool get isActive => status.isActive;

  String get statusLabel {
    switch (status.state) {
      case FastingState.inactive:
        return FastingStrings.inactive;
      case FastingState.fasting:
        return FastingStrings.fasting;
      case FastingState.feeding:
        return FastingStrings.feeding;
      case FastingState.completed:
        return FastingStrings.completed;
    }
  }

  String get protocolLabel {
    final protocol = selectedProtocol;
    if (protocol == null) {
      return FastingStrings.selectProtocolPlaceholder;
    }
    final hours = protocol.fastingMinutes ~/ 60;
    return '${protocol.name} • ${hours}h';
  }

  String get elapsedLabel => _formatDuration(status.elapsed);

  String get remainingLabel => _formatDuration(status.remaining);

  double get progress {
    final total = selectedProtocol?.fastingDuration ?? Duration.zero;
    final totalSeconds = total.inSeconds;
    if (totalSeconds == 0) return 0.0;
    return (status.elapsed.inSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  bool get canChangeProtocol {
    if (isLoading) return false;
    final current = session;
    if (current == null) return true;
    return current.status == FastingSessionStatus.ended;
  }

  String get protocolHelperText => FastingStrings.protocolHelper;

  String get primaryButtonLabel =>
      isActive ? FastingStrings.endFasting : FastingStrings.startFasting;

  bool get primaryButtonIsDestructive => isActive;

  FastingUiState copyWith({
    bool? isLoading,
    List<FastingProtocol>? protocols,
    FastingProtocol? selectedProtocol,
    FastingSession? session,
    FastingStatus? status,
    String? screenError,
    UiMessage? uiMessage,
  }) {
    return FastingUiState(
      isLoading: isLoading ?? this.isLoading,
      protocols: protocols ?? this.protocols,
      selectedProtocol: selectedProtocol ?? this.selectedProtocol,
      session: session ?? this.session,
      status: status ?? this.status,
      screenError: screenError,
      uiMessage: uiMessage,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        protocols,
        selectedProtocol,
        session,
        status,
        screenError,
        uiMessage,
      ];

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final h = hours.toString().padLeft(2, '0');
    final m = minutes.toString().padLeft(2, '0');
    final s = seconds.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

final fastingEngineProvider = Provider<FastingEngine>(
  (ref) => const FastingEngine(),
);

final currentUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) throw StateError('Usuário não autenticado');
  return user.uid;
});

class FastingController extends Notifier<FastingUiState> {
  Timer? _ticker;
  final Uuid _uuid = const Uuid();

  FastingRepository get _repository => ref.read(fastingRepositoryProvider);
  FastingEngine get _engine => ref.read(fastingEngineProvider);
  Clock get _clock => ref.read(clockProvider);
  NotificationsService get _notifications =>
      ref.read(notificationsServiceProvider);
  String get _userId => ref.read(currentUserIdProvider);

  @override
  FastingUiState build() {
    state = FastingUiState.initial();
    Future.microtask(_load);
    ref.onDispose(_stopTicker);
    return state;
  }

  Future<void> _load() async {
    try {
      state = state.copyWith(isLoading: true, screenError: null);

      final protocols = await _repository.listProtocols();
      final selectedProtocol = await _repository.getSelectedProtocol(
        _userId,
      );
      var session = await _repository.getActiveSession(_userId);
      final now = _clock.now();

      if (session != null && session.remaining(now) == Duration.zero) {
        session = await _completeSession(session, now, notify: true);
      }

      final status = _buildStatus(
        now: now,
        session: session,
        protocol: selectedProtocol,
      );

      state = state.copyWith(
        isLoading: false,
        protocols: protocols,
        selectedProtocol: selectedProtocol,
        session: session,
        status: status,
        screenError: null,
      );

      await _syncNotifications(session, now);
      _syncTicker(session);
    } catch (_) {
      _setScreenError(FastingStrings.errorGeneric);
    }
  }

  Future<void> startSession() => start();
  Future<void> stopSession() => end();

  Future<void> selectProtocol(String protocolId) async {
    final session = state.session;
    if (session != null && session.status != FastingSessionStatus.ended) {
      _emitError(FastingStrings.errorChangeProtocol);
      return;
    }

    try {
      await _repository.setSelectedProtocol(_userId, protocolId);
      final selected = await _repository.getSelectedProtocol(_userId);

      final now = _clock.now();
      final status = _buildStatus(
        now: now,
        session: state.session,
        protocol: selected,
      );

      state = state.copyWith(
        selectedProtocol: selected,
        status: status,
        screenError: null,
        uiMessage: null,
      );
    } catch (_) {
      _emitError(FastingStrings.errorGeneric);
    }
  }

  Future<void> start() async {
    final protocol = state.selectedProtocol;
    if (protocol == null) {
      _emitError(FastingStrings.errorSelectProtocol);
      return;
    }

    final existing = state.session;
    if (existing != null && existing.status == FastingSessionStatus.running) {
      _emitError(FastingStrings.errorActiveSession);
      return;
    }

    final now = _clock.now();
    final session = _engine.start(
      id: _uuid.v4(),
      userId: _userId,
      protocol: protocol,
      now: now,
    );

    await _repository.saveActiveSession(_userId, session);

    await _notifications.showNow(
      id: _notificationIdForSession(session.id),
      title: FastingStrings.notifStartedTitle,
      body: FastingStrings.notifStartedBody,
    );
    await _scheduleEndNotification(session, now);

    state = state.copyWith(
      session: session,
      status: _buildStatus(
        now: now,
        session: session,
        protocol: protocol,
      ),
      screenError: null,
      uiMessage: null,
    );

    _syncTicker(session);
  }

  Future<void> end() async {
    final session = state.session;
    final protocol = state.selectedProtocol;
    if (session == null || protocol == null) return;

    final now = _clock.now();
    final ended = _engine.end(session: session, now: now);

    await _repository.saveActiveSession(_userId, ended);
    await _repository.clearActiveSession(_userId);
    await _notifications.cancel(_notificationIdForSession(ended.id));

    await _notifications.showNow(
      id: _notificationIdForSession(ended.id),
      title: FastingStrings.notifEndedTitle,
      body: FastingStrings.notifEndedBody,
    );

    state = state.copyWith(
      session: ended,
      status: _buildStatus(
        now: now,
        session: ended,
        protocol: protocol,
      ),
      screenError: null,
      uiMessage: null,
    );

    _syncTicker(ended);
  }

  void consumeMessage() {
    state = state.copyWith(uiMessage: null);
  }

  Future<void> _syncNotifications(FastingSession? session, DateTime now) async {
    if (session == null) return;

    if (session.status == FastingSessionStatus.running) {
      await _scheduleEndNotification(session, now);
    } else {
      await _notifications.cancel(
        _notificationIdForSession(session.id),
      );
    }
  }

  int _notificationIdForSession(String sessionId) {
    final normalized = sessionId.replaceAll('-', '');
    if (normalized.length >= 8) {
      final slice = normalized.substring(0, 8);
      final parsed = int.tryParse(slice, radix: 16);
      if (parsed != null) return parsed & 0x7fffffff;
    }
    return sessionId.hashCode & 0x7fffffff;
  }

  Future<void> _scheduleEndNotification(
    FastingSession session,
    DateTime now,
  ) async {
    final remaining = session.remaining(now);
    if (remaining == Duration.zero) return;

    await _notifications.scheduleFastingEnd(
      id: _notificationIdForSession(session.id),
      when: now.add(remaining),
      title: FastingStrings.notifCompletedTitle,
      body: FastingStrings.notifCompletedBodyAlt,
    );
  }

  FastingStatus _buildStatus({
    required DateTime now,
    required FastingSession? session,
    required FastingProtocol? protocol,
  }) {
    if (session == null || protocol == null) {
      return FastingStatus.inactive();
    }

    final elapsed = session.elapsed(now);
    final remaining = session.remaining(now);
    final total = protocol.fastingDuration;

    if (remaining == Duration.zero) {
      return FastingStatus(
        state: FastingState.completed,
        elapsed: total,
        remaining: Duration.zero,
        total: total,
        phaseStartedAt: session.startAt,
        phaseEndsAt: session.endAtPlanned,
        session: session,
        protocol: protocol,
      );
    }

    if (session.status == FastingSessionStatus.paused ||
        session.status == FastingSessionStatus.ended) {
      return FastingStatus(
        state: FastingState.inactive,
        elapsed: elapsed,
        remaining: remaining,
        total: total,
        phaseStartedAt: session.startAt,
        phaseEndsAt: session.endAtPlanned,
        session: session,
        protocol: protocol,
      );
    }

    return FastingStatus.fasting(
      session: session,
      protocol: protocol,
      phaseStartedAt: session.startAt,
      phaseEndsAt: session.endAtPlanned,
      elapsed: elapsed,
      remaining: remaining,
    );
  }

  void _syncTicker(FastingSession? session) {
    if (session != null && session.status == FastingSessionStatus.running) {
      _startTicker();
    } else {
      _stopTicker();
    }
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refresh(),
    );
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _refresh() async {
    final session = state.session;
    final protocol = state.selectedProtocol;
    if (session == null || protocol == null) {
      _stopTicker();
      return;
    }

    if (session.status != FastingSessionStatus.running) {
      _stopTicker();
      return;
    }

    final now = _clock.now();

    if (session.remaining(now) == Duration.zero) {
      final ended = await _completeSession(
        session,
        now,
        notify: true,
      );
      state = state.copyWith(
        session: ended,
        status: _buildStatus(
          now: now,
          session: ended,
          protocol: protocol,
        ),
      );
      _stopTicker();
      return;
    }

    state = state.copyWith(
      status: _buildStatus(
        now: now,
        session: session,
        protocol: protocol,
      ),
    );
  }

  Future<FastingSession> _completeSession(
    FastingSession session,
    DateTime now, {
    required bool notify,
  }) async {
    final ended = _engine.end(session: session, now: now);
    await _repository.saveActiveSession(_userId, ended);
    await _repository.clearActiveSession(_userId);
    await _notifications.cancel(_notificationIdForSession(ended.id));
    if (notify) {
      await _notifications.showNow(
        id: _notificationIdForSession(ended.id),
        title: FastingStrings.notifCompletedTitle,
        body: FastingStrings.notifCompletedBody,
      );
    }
    return ended;
  }

  void _emitError(String message) {
    state = state.copyWith(
      isLoading: false,
      screenError: null,
      uiMessage: UiMessage(type: UiMessageType.error, text: message),
    );
  }

  void _setScreenError(String message) {
    state = state.copyWith(
      isLoading: false,
      screenError: message,
      uiMessage: null,
    );
  }
}

final fastingControllerProvider =
    NotifierProvider<FastingController, FastingUiState>(
  FastingController.new,
);
