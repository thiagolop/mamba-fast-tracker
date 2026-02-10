import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/ui/ui_message.dart';
import '../../data/auth_repository.dart';
import '../auth_strings.dart';

class AuthUiState extends Equatable {
  const AuthUiState({
    required this.isLoading,
    required this.canSubmit,
    this.emailError,
    this.passwordError,
    this.screenError,
    this.uiMessage,
  });

  final bool isLoading;
  final bool canSubmit;
  final String? emailError;
  final String? passwordError;
  final String? screenError;
  final UiMessage? uiMessage;

  factory AuthUiState.initial() {
    return const AuthUiState(
      isLoading: false,
      canSubmit: false,
    );
  }

  AuthUiState copyWith({
    bool? isLoading,
    bool? canSubmit,
    String? emailError,
    String? passwordError,
    String? screenError,
    UiMessage? uiMessage,
  }) {
    return AuthUiState(
      isLoading: isLoading ?? this.isLoading,
      canSubmit: canSubmit ?? this.canSubmit,
      emailError: emailError ?? this.emailError,
      passwordError: passwordError ?? this.passwordError,
      screenError: screenError,
      uiMessage: uiMessage,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        canSubmit,
        emailError,
        passwordError,
        screenError,
        uiMessage,
      ];
}

class AuthController extends Notifier<AuthUiState> {
  String _email = '';
  String _password = '';

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthUiState build() {
    return AuthUiState.initial();
  }

  void updateCredentials({required String email, required String password}) {
    _email = email.trim();
    _password = password;

    _setFieldErrors(showEmptyErrors: false);
  }

  Future<void> signIn({required String email, required String password}) async {
    _email = email.trim();
    _password = password;
    if (!_setFieldErrors(showEmptyErrors: true)) {
      state = state.copyWith(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, screenError: null, uiMessage: null);
    try {
      await _repository.signInWithEmail(
        email: _email,
        password: _password,
      );
      state = state.copyWith(isLoading: false);
    } catch (error) {
      final failure = _mapFailure(error);
      _emitError(failure.message);
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    _email = email.trim();
    _password = password;
    if (!_setFieldErrors(showEmptyErrors: true)) {
      state = state.copyWith(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, screenError: null, uiMessage: null);
    try {
      await _repository.registerWithEmail(
        email: _email,
        password: _password,
      );
      state = state.copyWith(isLoading: false);
      _emitSuccess(AuthStrings.signUpSuccess);
    } catch (error) {
      final failure = _mapFailure(error);
      _emitError(failure.message);
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }

  void consumeMessage() {
    state = state.copyWith(uiMessage: null);
  }

  void _emitError(String message) {
    state = state.copyWith(
      isLoading: false,
      screenError: null,
      uiMessage: UiMessage(type: UiMessageType.error, text: message),
    );
  }

  void _emitSuccess(String message) {
    state = state.copyWith(
      screenError: null,
      uiMessage: UiMessage(type: UiMessageType.success, text: message),
    );
  }

  bool _setFieldErrors({required bool showEmptyErrors}) {
    String? emailError;
    if (_email.isEmpty) {
      emailError = showEmptyErrors ? AuthStrings.validationEmailEmpty : null;
    } else if (!_isValidEmail(_email)) {
      emailError = AuthStrings.validationEmail;
    }

    String? passwordError;
    if (_password.isEmpty) {
      passwordError =
          showEmptyErrors ? AuthStrings.validationPasswordEmpty : null;
    } else if (_password.length < 6) {
      passwordError = AuthStrings.validationPasswordShort;
    }

    final canSubmit = _isValidEmail(_email) && _password.length >= 6;
    state = state.copyWith(
      canSubmit: canSubmit,
      emailError: emailError,
      passwordError: passwordError,
      screenError: null,
      uiMessage: null,
    );

    return canSubmit;
  }

  bool _isValidEmail(String email) {
    return email.isNotEmpty && email.contains('@');
  }

  AppFailure _mapFailure(Object error) {
    if (error is AppFailure) return error;
    if (error is Exception) {
      if (error is FirebaseAuthException) {
        return AppFailure.fromFirebaseAuth(error);
      }
    }
    return AppFailure.unknown(error);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthUiState>(AuthController.new);
