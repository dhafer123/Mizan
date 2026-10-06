import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/auth_providers.dart';
import '../../../../core/result/result.dart';
import '../../domain/usecases/validate_credentials.dart';
import '../shared/auth_form_errors.dart';
import '../shared/form_error_text.dart';
import '../shared/password_field.dart';

/// Create an account. Pops `true` once it exists and this phone is signed in.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _errors = const AuthFormErrors();
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
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
    final result = await ref.read(signUpProvider)(
      email: _email.text,
      password: _password.text,
      displayName: _name.text,
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

  @override
  Widget build(BuildContext context) {
    final formError = _errors[AuthField.form];
    return Scaffold(
      appBar: AppBar(title: const Text('Create an account')),
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(
                controller: _name,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clear(AuthField.displayName),
                decoration: InputDecoration(
                  labelText: 'Name (optional)',
                  helperText: 'Roommates see this in shared groups.',
                  errorText: _errors[AuthField.displayName],
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
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
                  errorMaxLines: 2,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                enabled: !_busy,
                label: 'Password',
                autofillHint: AutofillHints.newPassword,
                helperText:
                    'At least ${ValidateCredentials.minPasswordLength} '
                    'characters.',
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
                    : const Text('Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
