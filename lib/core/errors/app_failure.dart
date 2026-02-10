import 'package:firebase_auth/firebase_auth.dart';

class AppFailure {
  const AppFailure({
    required this.code,
    required this.message,
    this.original,
  });

  final String code;
  final String message;
  final Object? original;

  factory AppFailure.unknown(Object error) {
    return AppFailure(
      code: 'unknown',
      message: 'Não foi possível concluir. Tente novamente.',
      original: error,
    );
  }

  factory AppFailure.fromFirebaseAuth(FirebaseAuthException error) {
    return AppFailure(
      code: error.code,
      message: _firebaseAuthMessage(error.code),
      original: error,
    );
  }

  static String _firebaseAuthMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Digite um e-mail válido.';
      case 'user-not-found':
        return 'Conta não encontrada.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'email-already-in-use':
        return 'Este e-mail já está em uso.';
      case 'weak-password':
        return 'A senha deve ter pelo menos 6 caracteres.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente em alguns minutos.';
      case 'network-request-failed':
        return 'Sem conexão. Verifique sua internet.';
      default:
        return 'Não foi possível concluir. Tente novamente.';
    }
  }
}
