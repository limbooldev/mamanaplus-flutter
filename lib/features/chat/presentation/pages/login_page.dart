import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/auth_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  var _register = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MamanaPlus')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password (min 8)'),
              obscureText: true,
            ),
            if (_register) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (_register) {
                  context.read<AuthCubit>().register(
                        _email.text.trim(),
                        _password.text,
                        _name.text.trim(),
                      );
                } else {
                  context.read<AuthCubit>().login(
                        _email.text.trim(),
                        _password.text,
                      );
                }
              },
              child: Text(_register ? 'Register' : 'Login'),
            ),
            TextButton(
              onPressed: () => setState(() => _register = !_register),
              child: Text(_register ? 'Have an account? Login' : 'Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
