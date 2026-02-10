import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth_strings.dart';
import '../controllers/auth_controller.dart';
import '../widgets/widgets.dart';

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

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_syncCredentials);
    _passwordController.addListener(_syncCredentials);
  }

  @override
  void dispose() {
    _emailController.removeListener(_syncCredentials);
    _passwordController.removeListener(_syncCredentials);
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _syncCredentials() {
    ref.read(authControllerProvider.notifier).updateCredentials(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  Future<void> _submit() async {
    final controller = ref.read(authControllerProvider.notifier);
    final email = _emailController.text;
    final password = _passwordController.text;

    if (_isRegister) {
      await controller.signUp(email: email, password: password);
    } else {
      await controller.signIn(email: email, password: password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final canSubmit = state.canSubmit && !state.isLoading;

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
                              AuthStrings.title,
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1C1C1C),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AuthStrings.subtitle,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF1C1C1C),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AuthStrings.description,
                              style: textTheme.bodyMedium?.copyWith(
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
                              AuthInputField(
                                focusNode: _emailFocus,
                                controller: _emailController,
                                label: AuthStrings.emailLabel,
                                hint: AuthStrings.emailHint,
                                keyboardType: TextInputType.emailAddress,
                                errorText: state.emailError,
                              ),
                              const SizedBox(height: 16),
                              AuthInputField(
                                focusNode: _passwordFocus,
                                controller: _passwordController,
                                label: AuthStrings.passwordLabel,
                                hint: AuthStrings.passwordHint,
                                obscureText: _obscure,
                                errorText: state.passwordError,
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
                          onPressed: canSubmit ? _submit : null,
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
                                        AuthStrings.primaryButtonLoading,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    AuthStrings.primaryButton,
                                    key: const ValueKey('idle'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (state.screenError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          state.screenError!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        AuthStrings.privacyHelper,
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF8A8A8A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AuthStrings.noAccount,
                            style: textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6F6F6F),
                            ),
                          ),
                          GestureDetector(
                            onTap: state.isLoading
                                ? null
                                : () =>
                                    setState(() => _isRegister = !_isRegister),
                            child: Text(
                              AuthStrings.createNow,
                              style: textTheme.bodyMedium?.copyWith(
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
