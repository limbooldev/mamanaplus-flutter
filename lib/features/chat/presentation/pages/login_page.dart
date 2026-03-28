import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (_, state) => state is AuthFailure,
      listener: (context, state) {
        if (state is AuthFailure) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.appTitle)),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _email,
                  decoration: InputDecoration(labelText: l10n.labelEmail),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  decoration: InputDecoration(labelText: l10n.labelPassword),
                  obscureText: true,
                  enabled: !isLoading,
                ),
                if (_register) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(labelText: l10n.labelDisplayName),
                    enabled: !isLoading,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () {
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
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_register ? l10n.buttonRegister : l10n.buttonLogin),
                ),
                TextButton(
                  onPressed: isLoading ? null : () => setState(() => _register = !_register),
                  child: Text(_register ? l10n.toggleToLogin : l10n.toggleToRegister),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
