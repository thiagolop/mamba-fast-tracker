import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/notifications/notifications_service.dart';
import '../../../core/time/clock.dart';
import '../../auth/data/auth_repository.dart';
import '../data/fasting_repository.dart';
import '../domain/fasting_engine.dart';
import '../domain/fasting_protocol.dart';
import '../domain/fasting_session.dart';
import '../domain/fasting_status.dart';

class FastingUiState extends Equatable {
  const FastingUiState({
    required this.isLoading,
    required this.protocols,
    required this.status,
    this.selectedProtocol,
    this.session,
    this.errorMessage,
  });

  final bool isLoading;
  final List<FastingProtocol> protocols;
  final FastingProtocol? selectedProtocol;
  final FastingSession? session;
  final FastingStatus status;
  final String? errorMessage;

  factory FastingUiState.initial() {
    return FastingUiState(
      isLoading: true,
      protocols: const [],
      status: FastingStatus.inactive(),
    );
  }

  FastingUiState copyWith({
    bool? isLoading,
    List<FastingProtocol>? protocols,
    FastingProtocol? selectedProtocol,
    FastingSession? session,
    FastingStatus? status,
    String? errorMessage,
  }) {
    return FastingUiState(
      isLoading: isLoading ?? this.isLoading,
      protocols: protocols ?? this.protocols,
      selectedProtocol: selectedProtocol ?? this.selectedProtocol,
      session: session ?? this.session,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    protocols,
    selectedProtocol,
    session,
    status,
    errorMessage,
  ];
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

  FastingRepository get _repository =>
      ref.read(fastingRepositoryProvider);
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
      state = state.copyWith(isLoading: true, errorMessage: null);

      final protocols = await _repository.listProtocols();
      final selectedProtocol = await _repository.getSelectedProtocol(
        _userId,
      );
      var session = await _repository.getActiveSession(_userId);
      final now = _clock.now();

      if (session != null &&
          session.remaining(now) == Duration.zero) {
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
      );

      await _syncNotifications(session, now);
      _syncTicker(session);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  // =========================================================
  // ✅ FIX 1: manter compatibilidade com a UI (aliases)
  // =========================================================
  Future<void> startSession() => start();
  Future<void> stopSession() => end();

  // =========================================================
  // ✅ FIX 2: selectProtocol (usado pela UI)
  // =========================================================
  Future<void> selectProtocol(String protocolId) async {
    // se existir uma sessão ativa, bloqueia troca de protocolo
    final session = state.session;
    if (session != null && session.status != FastingSessionStatus.ended) {
      state = state.copyWith(
        errorMessage: 'Finalize o jejum antes de trocar',
      );
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
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  // =========================================================
  // Core actions
  // =========================================================
  Future<void> start() async {
    final protocol = state.selectedProtocol;
    if (protocol == null) {
      state = state.copyWith(errorMessage: 'Selecione um protocolo');
      return;
    }

    final existing = state.session;
    if (existing != null && existing.status == FastingSessionStatus.running) {
      state = state.copyWith(
        errorMessage: 'Já existe um jejum ativo',
      );
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
      title: 'Jejum iniciado',
      body: 'Seu jejum começou agora.',
    );
    await _scheduleEndNotification(session, now);

    state = state.copyWith(
      session: session,
      status: _buildStatus(
        now: now,
        session: session,
        protocol: protocol,
      ),
      errorMessage: null,
    );

    _syncTicker(session);
  }

  // Se você ainda não implementou pause/resume, pode deixar assim por enquanto.
  // (Depois a gente adiciona.)
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
      title: 'Jejum encerrado',
      body: 'Seu jejum foi finalizado.',
    );

    state = state.copyWith(
      session: ended,
      status: _buildStatus(
        now: now,
        session: ended,
        protocol: protocol,
      ),
      errorMessage: null,
    );

    _syncTicker(ended);
  }

  // =========================================================
  // helpers
  // =========================================================
  Future<void> _syncNotifications(
    FastingSession? session,
    DateTime now,
  ) async {
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
      title: 'Jejum concluído',
      body: 'Sua janela de jejum terminou.',
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
    // Mantém simples por enquanto (depois implementamos o status real)
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
        title: 'Jejum concluído',
        body: 'Você terminou o jejum.',
      );
    }
    return ended;
  }
}

final fastingControllerProvider =
    NotifierProvider<FastingController, FastingUiState>(
      FastingController.new,
    );
