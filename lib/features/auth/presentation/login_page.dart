import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegister = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_notifyController);
    _passwordController.addListener(_notifyController);
  }

  @override
  void dispose() {
    _emailController.removeListener(_notifyController);
    _passwordController.removeListener(_notifyController);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _notifyController() {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegister ? 'Criar conta' : 'Entrar'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha'),
            ),
            const SizedBox(height: 24),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (state.infoMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  state.infoMessage!,
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ),
            ElevatedButton(
              onPressed:
                  state.isLoading || !state.canSubmit ? null : _submit,
              child: state.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isRegister ? 'Criar conta' : 'Entrar'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: state.isLoading
                  ? null
                  : () => setState(() => _isRegister = !_isRegister),
              child: Text(
                _isRegister ? 'Já tenho conta' : 'Criar nova conta',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
