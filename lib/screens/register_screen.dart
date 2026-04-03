import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/providers/auth_provider.dart';
import 'package:fsdmovil/widgets/app_logo.dart';

const _pink = Color(0xFFE8365D);
const _darkBg = Color(0xFF0F1017);
const _fieldBg = Color(0xFF1E2030);
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
  final _confirmPasswordCtrl = TextEditingController();

  // OTP verification step
  int _step = 0; // 0 = form, 1 = verify code
  final List<TextEditingController> _codeCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _codeFocus = List.generate(6, (_) => FocusNode());

  // Datos guardados al pasar al paso 2
  String _savedFirstName = '';
  String _savedLastName = '';
  String _savedEmail = '';
  String _savedPassword = '';

  // Contador reenvío OTP
  int _resendSeconds = 0;
  Timer? _resendTimer;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
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

  String? _validateFields() {
    if (_firstNameCtrl.text.trim().isEmpty) return 'El nombre es requerido.';
    if (_lastNameCtrl.text.trim().isEmpty) return 'El apellido es requerido.';

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return 'El email es requerido.';
    final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$');
    if (!emailRegex.hasMatch(email)) return 'Ingresa un email válido.';

    final password = _passwordCtrl.text;
    if (password.isEmpty) return 'La contraseña es requerida.';
    if (password.length < 8) return 'La contraseña debe tener al menos 8 caracteres.';
    if (!RegExp(r'[A-Z]').hasMatch(password)) return 'La contraseña debe tener al menos una mayúscula.';
    if (!RegExp(r'[0-9]').hasMatch(password)) return 'La contraseña debe tener al menos un número.';

    if (_confirmPasswordCtrl.text.isEmpty) return 'Confirma tu contraseña.';
    if (password != _confirmPasswordCtrl.text) return 'Las contraseñas no coinciden.';

    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final validationError = _validateFields();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await ref
        .read(authProvider.notifier)
        .register(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          passwordConfirm: _confirmPasswordCtrl.text,
        );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
      return;
    }

    setState(() {
      _loading = false;
      _step = 1; // ir al paso de verificación
      _error = null;
      // Guardar datos antes de que los controllers puedan cambiar
      _savedFirstName = _firstNameCtrl.text.trim();
      _savedLastName = _lastNameCtrl.text.trim();
      _savedEmail = _emailCtrl.text.trim();
      _savedPassword = _passwordCtrl.text;
    });
    _startResendTimer();
  }

  Future<void> _verifyCode() async {
    FocusScope.of(context).unfocus();

    final code = _codeCtrl.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() => _error = 'Ingresa el código de 6 dígitos.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await ref.read(authProvider.notifier).verifyEmailCode(
      email: _savedEmail,
      code: code,
      firstName: _savedFirstName,
      lastName: _savedLastName,
      password: _savedPassword,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
      return;
    }

    setState(() => _loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cuenta creada con éxito! Inicia sesión.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
    context.go('/login');
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) t.cancel();
      });
    });
  }

  Future<void> _resendCode() async {
    if (_resendSeconds > 0) return;
    setState(() => _error = null);
    final error = await ref
        .read(authProvider.notifier)
        .resendVerificationCode(email: _savedEmail);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
    } else {
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código reenviado. Revisa tu correo.'),
          backgroundColor: Color(0xFF1E2030),
        ),
      );
    }
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
        return const Color(0xFF2A2D3A);
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
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    for (final c in _codeCtrl) c.dispose();
    for (final f in _codeFocus) f.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strengthColor = _strengthColor(_passwordStrength);
    final strengthLabel = _strengthLabel(_passwordStrength);
    final strengthValue = _passwordStrength.index / 4.0;

    return Scaffold(
      backgroundColor: _darkBg,
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
            child: _step == 1
                ? _buildVerifyStep()
                : _buildFormStep(strengthColor, strengthLabel, strengthValue),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const AppLogo(size: 50),
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
        const SizedBox(height: 40),
        const Text(
          'Verifica tu',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text(
          'correo electrónico',
          style: TextStyle(
            color: _pink,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Enviamos un código de 6 dígitos a\n${_emailCtrl.text.trim()}',
          style: const TextStyle(color: _textGrey, fontSize: 14),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            return SizedBox(
              width: 46,
              height: 56,
              child: TextField(
                controller: _codeCtrl[i],
                focusNode: _codeFocus[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: _fieldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _pink, width: 2),
                  ),
                ),
                onChanged: (v) {
                  if (v.isNotEmpty && i < 5) {
                    _codeFocus[i + 1].requestFocus();
                  } else if (v.isEmpty && i > 0) {
                    _codeFocus[i - 1].requestFocus();
                  }
                },
              ),
            );
          }),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: _pink, fontSize: 13),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _verifyCode,
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
                    'Verificar cuenta',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: (_loading || _resendSeconds > 0) ? null : _resendCode,
            child: RichText(
              text: TextSpan(
                children: [
                  const TextSpan(
                    text: '¿No recibiste el código? ',
                    style: TextStyle(color: _textGrey, fontSize: 14),
                  ),
                  TextSpan(
                    text: _resendSeconds > 0
                        ? 'Reenviar (${_resendSeconds}s)'
                        : 'Reenviar',
                    style: TextStyle(
                      color: _resendSeconds > 0 ? _textGrey : _pink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () => setState(() {
              _step = 0;
              _error = null;
              for (final c in _codeCtrl) c.clear();
            }),
            child: const Text(
              '← Cambiar correo',
              style: TextStyle(color: _textGrey, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormStep(
    Color strengthColor,
    String strengthLabel,
    double strengthValue,
  ) {
    return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppLogo(size: 50),
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

                if (_passwordStrength != _PasswordStrength.none) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: strengthValue,
                      minHeight: 4,
                      backgroundColor: const Color(0xFF2A2D3A),
                      valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strengthLabel,
                    style: TextStyle(color: strengthColor, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 20),

                const Text(
                  'Confirm Password',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmPasswordCtrl,
                  obscureText: _obscureConfirmPassword,
                  style: const TextStyle(color: Colors.white),
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
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _textGrey,
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: _pink, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 28),

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

                Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(color: _textGrey, fontSize: 11),
                      children: [
                        TextSpan(
                          text:
                              'By clicking "Create Account", you agree to our ',
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
            );
  }
}
