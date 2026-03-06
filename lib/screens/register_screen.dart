import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// lib/providers: auth_provider.dart (Logica de autenticación y estado global)
import 'package:fsdmovil/providers/auth_provider.dart';

// lib/services: auth_service.dart (Comunicación con API para login/registro)
// import 'package:fsdmovil/services/auth_service.dart';

const _pink = Color(0xFFE8365D);
const _darkBg = Color(0xFF1C1C1E);
const _fieldBg = Color(0xFF2C2C2E);
const _textGrey = Color(0xFF8E8E93);

enum _PasswordStrength { none, weak, fair, good, strong }

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;
  _PasswordStrength _passwordStrength = _PasswordStrength.none;

  _PasswordStrength _evaluateStrength(String password) {
    if (password.isEmpty) return _PasswordStrength.none;
    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
    if (score <= 1) return _PasswordStrength.weak;
    if (score == 2) return _PasswordStrength.fair;
    if (score == 3) return _PasswordStrength.good;
    return _PasswordStrength.strong;
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await ref
        .read(authProvider.notifier)
        .register(
          _firstNameCtrl.text,
          _lastNameCtrl.text,
          _emailCtrl.text,
          _passwordCtrl.text,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
      return;
    }
    context.go('/dashboard');
  }

  Color _strengthColor(_PasswordStrength s) {
    switch (s) {
      case _PasswordStrength.weak:
        return _pink;
      case _PasswordStrength.fair:
        return Colors.orange;
      case _PasswordStrength.good:
        return Colors.yellow;
      case _PasswordStrength.strong:
        return Colors.green;
      default:
        return const Color(0xFF3A3A3C);
    }
  }

  String _strengthLabel(_PasswordStrength s) {
    switch (s) {
      case _PasswordStrength.weak:
        return 'Weak password';
      case _PasswordStrength.fair:
        return 'Fair password';
      case _PasswordStrength.good:
        return 'Good password';
      case _PasswordStrength.strong:
        return 'Strong password';
      default:
        return '';
    }
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _textGrey),
    filled: true,
    fillColor: _fieldBg,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );

  @override
  Widget build(BuildContext context) {
    final strengthColor = _strengthColor(_passwordStrength);
    final strengthLabel = _strengthLabel(_passwordStrength);
    final strengthValue = _passwordStrength.index / 4.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.7, 0.7),
            radius: 0.6,
            colors: [Color(0x1FFF1744), Colors.transparent],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: logo
              Row(
                children: [
                  Image.asset(
                    'assets/images/logo_transparente.png',
                    width: 50,
                    height: 50,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'FSD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Título
              const Text(
                'Start documenting',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'better',
                style: TextStyle(
                  color: _pink,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join FSD, the premium SRS documentation platform.',
                style: TextStyle(color: _textGrey, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // First Name + Last Name (dos columnas)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'First Name',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _firstNameCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: _fieldDecoration('First Name'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Last Name',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _lastNameCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: _fieldDecoration('Last Name'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Email
              const Text(
                'Email',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration('name@company.com'),
              ),
              const SizedBox(height: 20),

              // Password
              const Text(
                'Password',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                onChanged: (v) =>
                    setState(() => _passwordStrength = _evaluateStrength(v)),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintStyle: const TextStyle(color: _textGrey),
                  filled: true,
                  fillColor: _fieldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _textGrey,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),

              // Barra de fuerza de contraseña
              if (_passwordStrength != _PasswordStrength.none) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: strengthValue,
                    minHeight: 4,
                    backgroundColor: const Color(0xFF3A3A3C),
                    valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  strengthLabel,
                  style: TextStyle(color: strengthColor, fontSize: 12),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: _pink, fontSize: 13),
                ),
              ],
              const SizedBox(height: 28),

              // Botón Create Account
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Already have an account
              Center(
                child: GestureDetector(
                  onTap: () =>
                      context.canPop() ? context.pop() : context.go('/login'),
                  child: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(color: _textGrey, fontSize: 14),
                        ),
                        TextSpan(
                          text: 'Login',
                          style: TextStyle(
                            color: _pink,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Terms
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(color: _textGrey, fontSize: 11),
                    children: [
                      TextSpan(
                        text: 'By clicking "Create Account", you agree to our ',
                      ),
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: ' and\n'),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
