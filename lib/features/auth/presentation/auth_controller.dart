import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../data/auth_repository.dart';

class AuthUiState extends Equatable {
  const AuthUiState({
    required this.isLoading,
    required this.canSubmit,
    this.errorMessage,
    this.infoMessage,
  });

  final bool isLoading;
  final bool canSubmit;
  final String? errorMessage;
  final String? infoMessage;

  factory AuthUiState.initial() {
    return const AuthUiState(
      isLoading: false,
      canSubmit: false,
    );
  }

  AuthUiState copyWith({
    bool? isLoading,
    bool? canSubmit,
    String? errorMessage,
    String? infoMessage,
  }) {
    return AuthUiState(
      isLoading: isLoading ?? this.isLoading,
      canSubmit: canSubmit ?? this.canSubmit,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        canSubmit,
        errorMessage,
        infoMessage,
      ];
}

class AuthController extends Notifier<AuthUiState> {
  Timer? _infoTimer;
  String _email = '';
  String _password = '';

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthUiState build() {
    ref.onDispose(() => _infoTimer?.cancel());
    return AuthUiState.initial();
  }

  void updateCredentials({required String email, required String password}) {
    _email = email.trim();
    _password = password.trim();
    final canSubmit = _email.isNotEmpty && _password.length >= 6;
    state = state.copyWith(canSubmit: canSubmit);
  }

  Future<void> signIn({required String email, required String password}) async {
    final emailTrim = email.trim();
    final passwordTrim = password.trim();

    final validation = _validate(emailTrim, passwordTrim);
    if (validation != null) {
      state = state.copyWith(
        errorMessage: validation,
        infoMessage: null,
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null, infoMessage: null);
    try {
      await _repository.signInWithEmail(
        email: emailTrim,
        password: passwordTrim,
      );
      state = state.copyWith(isLoading: false, errorMessage: null);
    } on FirebaseAuthException catch (error) {
      final failure = AppFailure.fromFirebaseAuth(error);
      state = state.copyWith(isLoading: false, errorMessage: failure.message);
    } catch (error) {
      final failure = AppFailure.unknown(error);
      state = state.copyWith(isLoading: false, errorMessage: failure.message);
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    final emailTrim = email.trim();
    final passwordTrim = password.trim();

    final validation = _validate(emailTrim, passwordTrim);
    if (validation != null) {
      state = state.copyWith(
        errorMessage: validation,
        infoMessage: null,
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null, infoMessage: null);
    try {
      await _repository.registerWithEmail(
        email: emailTrim,
        password: passwordTrim,
      );
      _setInfoMessage('Conta criada com sucesso.');
      state = state.copyWith(isLoading: false, errorMessage: null);
    } on FirebaseAuthException catch (error) {
      final failure = AppFailure.fromFirebaseAuth(error);
      state = state.copyWith(isLoading: false, errorMessage: failure.message);
    } catch (error) {
      final failure = AppFailure.unknown(error);
      state = state.copyWith(isLoading: false, errorMessage: failure.message);
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }

  String? _validate(String email, String password) {
    if (email.isEmpty || password.isEmpty) {
      return 'Informe e-mail e senha.';
    }
    if (password.length < 6) {
      return 'A senha deve ter pelo menos 6 caracteres.';
    }
    return null;
  }

  void _setInfoMessage(String message) {
    _infoTimer?.cancel();
    state = state.copyWith(infoMessage: message);
    _infoTimer = Timer(const Duration(seconds: 3), () {
      state = state.copyWith(infoMessage: null);
    });
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthUiState>(AuthController.new);
