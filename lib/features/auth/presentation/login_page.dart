import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isRegister = false;
  bool _obscure = true;
  bool _emailTouched = false;
  bool _passwordTouched = false;

  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_handleInputChange);
    _passwordController.addListener(_handleInputChange);
    _emailFocus.addListener(_handleFocusChange);
    _passwordFocus.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleInputChange);
    _passwordController.removeListener(_handleInputChange);
    _emailFocus.removeListener(_handleFocusChange);
    _passwordFocus.removeListener(_handleFocusChange);
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_emailFocus.hasFocus && _emailController.text.isNotEmpty) {
      _emailTouched = true;
    }
    if (!_passwordFocus.hasFocus && _passwordController.text.isNotEmpty) {
      _passwordTouched = true;
    }
    _validateFields();
  }

  void _handleInputChange() {
    if (_emailController.text.isNotEmpty) {
      _emailTouched = true;
    }
    if (_passwordController.text.isNotEmpty) {
      _passwordTouched = true;
    }

    ref.read(authControllerProvider.notifier).updateCredentials(
          email: _emailController.text,
          password: _passwordController.text,
        );
    _validateFields();
  }

  void _validateFields() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = _emailTouched && !_isValidEmail(email)
          ? 'Digite um email válido.'
          : null;

      if (_passwordTouched) {
        if (password.isEmpty) {
          _passwordError = 'Digite sua senha.';
        } else if (password.length < 6) {
          _passwordError = 'A senha deve ter pelo menos 6 caracteres.';
        } else {
          _passwordError = null;
        }
      } else {
        _passwordError = null;
      }
    });
  }

  bool _isValidEmail(String email) {
    return email.isNotEmpty && email.contains('@');
  }

  Future<void> _submit() async {
    _emailTouched = true;
    _passwordTouched = true;
    _validateFields();

    final controller = ref.read(authControllerProvider.notifier);
    final email = _emailController.text;
    final password = _passwordController.text;

    if (_isRegister) {
      await controller.signUp(email: email, password: password);
    } else {
      await controller.signIn(email: email, password: password);
    }
  }

  String? _friendlyError(String? message) {
    if (message == null) return null;
    final lower = message.toLowerCase();
    if (lower.contains('conex') || lower.contains('internet')) {
      return 'Sem conexão. Verifique sua internet e tente novamente.';
    }
    if (lower.contains('senha') ||
        lower.contains('conta') ||
        lower.contains('email')) {
      return 'Email ou senha incorretos. Tenta de novo 🙂';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final isEmailValid = _isValidEmail(email);
    final isPasswordValid = password.length >= 6;
    final canSubmit = state.canSubmit && isEmailValid && isPasswordValid;

    final errorText = _friendlyError(state.errorMessage);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jejum inteligente.',
                              style: GoogleFonts.manrope(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1C1C1C),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No ritmo do seu corpo.',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF1C1C1C),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Acompanhe seu jejum, receba alertas e mantenha consistência.',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: const Color(0xFF6F6F6F),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _InputField(
                                focusNode: _emailFocus,
                                controller: _emailController,
                                label: 'Email',
                                hint: 'seu@email.com',
                                keyboardType: TextInputType.emailAddress,
                                errorText: _emailError,
                              ),
                              const SizedBox(height: 16),
                              _InputField(
                                focusNode: _passwordFocus,
                                controller: _passwordController,
                                label: 'Senha',
                                hint: '••••••••',
                                obscureText: _obscure,
                                errorText: _passwordError,
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() {
                                    _obscure = !_obscure;
                                  }),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              state.isLoading || !canSubmit ? null : _submit,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: state.isLoading
                                ? Row(
                                    key: const ValueKey('loading'),
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Entrando…',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    'Entrar no meu jejum',
                                    key: const ValueKey('idle'),
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: errorText == null
                            ? const SizedBox.shrink()
                            : Container(
                                key: const ValueKey('error'),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: colorScheme.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        errorText,
                                        style: TextStyle(
                                          color: colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      if (state.infoMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          state.infoMessage!,
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Seus dados ficam seguros com você.',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: const Color(0xFF8A8A8A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Ainda não tem conta? ',
                            style: GoogleFonts.manrope(
                              color: const Color(0xFF6F6F6F),
                            ),
                          ),
                          GestureDetector(
                            onTap: state.isLoading
                                ? null
                                : () =>
                                    setState(() => _isRegister = !_isRegister),
                            child: Text(
                              'Criar agora',
                              style: GoogleFonts.manrope(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.focusNode,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.errorText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: focusNode.hasFocus
            ? [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            autocorrect: false,
            obscureText: obscureText,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              filled: true,
              fillColor: colorScheme.surfaceVariant,
              suffixIcon: suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: errorText == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      errorText!,
                      style: TextStyle(
                        color: colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
