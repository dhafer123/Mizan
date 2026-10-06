import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/auth_providers.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/result/result.dart';
import '../shared/auth_form_errors.dart';
import '../shared/form_error_text.dart';
import '../shared/password_field.dart';

/// Sign in to an existing account. Pops `true` once signed in (also after
/// creating an account from here).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _errors = const AuthFormErrors();
  var _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clear(AuthField field) {
    final cleared = _errors.clear(field).clear(AuthField.form);
    if (!identical(cleared, _errors)) setState(() => _errors = cleared);
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _errors = const AuthFormErrors();
    });
    final result = await ref.read(logInProvider)(
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(:final failure):
        setState(() {
          _busy = false;
          _errors = AuthFormErrors(failure);
        });
    }
  }

  Future<void> _createAccount() async {
    final created = await context.push<bool>(AppRoutes.signUp);
    if (created == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formError = _errors[AuthField.form];
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Sign in to back up your data and share expenses with '
                'roommates. Mizan also works without an account.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clear(AuthField.email),
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText: _errors[AuthField.email],
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                enabled: !_busy,
                label: 'Password',
                autofillHint: AutofillHints.password,
                errorText: _errors[AuthField.password],
                onChanged: (_) => _clear(AuthField.password),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              if (formError != null) FormErrorText(formError),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign in'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _createAccount,
                child: const Text('New here? Create an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
