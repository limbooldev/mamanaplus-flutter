import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mamana_plus/l10n/app_localizations.dart';

import '../../../../shared/ui/ui.dart';
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
  var _passwordVisible = false;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(isDark: isDark, isRegister: _register),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionLabel(
                          text: _register ? l10n.buttonRegister : l10n.buttonLogin,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _email,
                          decoration: InputDecoration(
                            labelText: l10n.labelEmail,
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: AppColors.subtitleLight,
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _password,
                          decoration: InputDecoration(
                            labelText: l10n.labelPassword,
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppColors.subtitleLight,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.subtitleLight,
                              ),
                              onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible,
                              ),
                            ),
                          ),
                          obscureText: !_passwordVisible,
                          textInputAction: _register
                              ? TextInputAction.next
                              : TextInputAction.done,
                          enabled: !isLoading,
                        ),
                        if (_register) ...[
                          const SizedBox(height: 14),
                          TextField(
                            controller: _name,
                            decoration: InputDecoration(
                              labelText: l10n.labelDisplayName,
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: AppColors.subtitleLight,
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                            enabled: !isLoading,
                          ),
                        ],
                        const SizedBox(height: 28),
                        FilledButton(
                          onPressed: isLoading ? null : () => _submit(context),
                          child: isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _register
                                      ? l10n.buttonRegister
                                      : l10n.buttonLogin,
                                ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: isLoading
                                ? null
                                : () => setState(() => _register = !_register),
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.subtitleLight,
                                ),
                                children: [
                                  TextSpan(
                                    text: _register
                                        ? 'Already have an account? '
                                        : "Don't have an account? ",
                                  ),
                                  TextSpan(
                                    text: _register
                                        ? l10n.toggleToLogin
                                        : l10n.toggleToRegister,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _submit(BuildContext context) {
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
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isDark, required this.isRegister});
  final bool isDark;
  final bool isRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.75),
            const Color(0xFF7B5FFF),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -30,
            right: -30,
            child: _Circle(size: 140, color: Colors.white.withValues(alpha: 0.07)),
          ),
          Positioned(
            bottom: 10,
            left: -20,
            child: _Circle(size: 100, color: Colors.white.withValues(alpha: 0.05)),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 48, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'MamanaPlus',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isRegister
                      ? 'Create your account'
                      : 'Welcome back!',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
      ),
    );
  }
}
