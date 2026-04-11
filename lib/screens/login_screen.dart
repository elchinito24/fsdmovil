import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;
import 'package:fsdmovil/providers/auth_provider.dart';

const _pink = Color(0xFFE8365D);
const _darkBg = Color(0xFF1C1C1E);
const _fieldBg = Color(0xFF2C2C2E);
const _textGrey = Color(0xFF8E8E93);
const _dividerColor = Color(0xFF3A3A3C);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  String? _error;

  String? _socialError;

  String? _validateEmail(String value) {
    if (value.isEmpty) return 'Email is required.';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email.';
    return null;
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) return 'Password is required.';
    if (value.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    final emailError = _validateEmail(email);
    if (emailError != null) {
      setState(() {
        _error = emailError;
      });
      return;
    }

    final passwordError = _validatePassword(password);
    if (passwordError != null) {
      setState(() {
        _error = passwordError;
      });
      return;
    }

    setState(() {
      _error = null;
    });

    final errorMsg = await ref.read(authProvider.notifier).login(email, password);

    if (!mounted) return;
    if (errorMsg != null) {
      setState(() {
        _error = errorMsg;
      });
      return;
    }

    context.go('/dashboard');
  }

  Future<void> _socialLogin(OAuthProvider provider) async {
    setState(() {
      _socialError = null;
    });
    final errorMsg = await ref.read(authProvider.notifier).socialLogin(provider);
    if (!mounted) return;
    if (errorMsg != null) {
      setState(() {
        _socialError = errorMsg;
      });
    }
    // La navegación la maneja ref.listen abajo cuando isAuthenticated cambia
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final constrainedWidth = screenWidth > 520 ? 460.0 : double.infinity;
    final isLoading = ref.watch(authProvider).isLoading;

    // Navega a dashboard en cuanto isAuthenticated cambia a true (cubre social login)
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!(previous?.isAuthenticated ?? false) && next.isAuthenticated) {
        context.go('/dashboard');
      }
    });

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
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constrainedWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        Image.asset(
                          'assets/images/logo_transparente.png',
                          width: 50,
                          height: 50,
                        ),
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
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Welcome ',
                            style: TextStyle(
                              color: _pink,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: 'back',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Log in to your FSD account to continue.',
                      style: TextStyle(color: _textGrey, fontSize: 14),
                    ),
                    const SizedBox(height: 36),
                    const Text(
                      'Email',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'name@company.com',
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
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Password',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (_) => isLoading ? null : _submit(),
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
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(color: _pink, fontSize: 13),
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
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Log in',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: () => context.push('/register'),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: "Don't have an account? ",
                                style: TextStyle(
                                  color: _textGrey,
                                  fontSize: 14,
                                ),
                              ),
                              TextSpan(
                                text: 'Sign up',
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
                    const Row(
                      children: [
                        Expanded(
                          child: Divider(color: _dividerColor, thickness: 1),
                        ),
                        Flexible(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR CONTINUE WITH',
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textGrey,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: _dividerColor, thickness: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_socialError != null) ...[
                      Text(
                        _socialError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _pink, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SocialButton(
                          label: 'Google',
                          icon: const _GoogleIcon(),
                          onTap: isLoading ? null : () => _socialLogin(OAuthProvider.google),
                        ),
                        const SizedBox(width: 16),
                        _SocialButton(
                          label: 'GitHub',
                          icon: const _GitHubIcon(),
                          onTap: isLoading ? null : () => _socialLogin(OAuthProvider.github),
                        ),
                        const SizedBox(width: 16),
                        _SocialButton(
                          label: 'Microsoft',
                          icon: const _MicrosoftIcon(),
                          onTap: isLoading ? null : () => _socialLogin(OAuthProvider.azure),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1.0,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

// Google icon (G multicolor)
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();
  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 22,
        fontWeight: FontWeight.bold,
        fontFamily: 'sans-serif',
      ),
    );
  }
}

// GitHub icon
class _GitHubIcon extends StatelessWidget {
  const _GitHubIcon();
  @override
  Widget build(BuildContext context) {
    return const FaIcon(FontAwesomeIcons.github, color: Colors.white, size: 22);
  }
}

// Microsoft icon (cuatro cuadros de colores)
class _MicrosoftIcon extends StatelessWidget {
  const _MicrosoftIcon();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, color: const Color(0xFFF25022)),
              const SizedBox(width: 2),
              Container(width: 10, height: 10, color: const Color(0xFF7FBA00)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(width: 10, height: 10, color: const Color(0xFF00A4EF)),
              const SizedBox(width: 2),
              Container(width: 10, height: 10, color: const Color(0xFFFFB900)),
            ],
          ),
        ],
      ),
    );
  }
}
