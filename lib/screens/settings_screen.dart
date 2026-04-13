import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/auth_service.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';

const _pink = Color(0xFFE8365D);
const _textGrey = Color(0xFF8E8E93);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String activeTab = 'general';

  String firstName = '';
  String lastName = '';
  String email = '';

  bool loadingProfile = true;
  bool savingProfile = false;
  bool savingPassword = false;
  bool deletingAccount = false;

  String currentPassword = '';
  String newPassword = '';
  String confirmPassword = '';

  String? generalFeedback;
  bool generalSuccess = true;

  String? securityFeedback;
  bool securitySuccess = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final user = await AuthService.getMe();

      if (!mounted) return;

      setState(() {
        firstName = (user['first_name'] ?? '').toString();
        lastName = (user['last_name'] ?? '').toString();
        email = (user['email'] ?? '').toString();
        loadingProfile = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        firstName = AuthService.firstName ?? '';
        lastName = AuthService.lastName ?? '';
        email = AuthService.userEmail ?? '';
        loadingProfile = false;
        generalFeedback = e.toString().replaceFirst('Exception: ', '');
        generalSuccess = false;
      });
    }
  }

  Future<void> saveProfile() async {
    setState(() {
      savingProfile = true;
      generalFeedback = null;
    });

    try {
      await AuthService.updateMe(firstName: firstName, lastName: lastName);

      if (!mounted) return;

      setState(() {
        generalFeedback = 'Perfil actualizado correctamente.';
        generalSuccess = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        generalFeedback = e.toString().replaceFirst('Exception: ', '');
        generalSuccess = false;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        savingProfile = false;
      });
    }
  }

  Future<void> changePassword() async {
    setState(() {
      securityFeedback = null;
    });

    if (currentPassword.trim().isEmpty ||
        newPassword.trim().isEmpty ||
        confirmPassword.trim().isEmpty) {
      setState(() {
        securityFeedback = 'Todos los campos son obligatorios.';
        securitySuccess = false;
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        securityFeedback = 'Las contraseñas nuevas no coinciden.';
        securitySuccess = false;
      });
      return;
    }

    setState(() {
      savingPassword = true;
    });

    try {
      await AuthService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      if (!mounted) return;

      setState(() {
        currentPassword = '';
        newPassword = '';
        confirmPassword = '';
        securityFeedback = 'Contraseña actualizada correctamente.';
        securitySuccess = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        securityFeedback = e.toString().replaceFirst('Exception: ', '');
        securitySuccess = false;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        savingPassword = false;
      });
    }
  }

  Future<void> deleteAccount() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              backgroundColor: Theme.of(ctx).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                'Eliminar cuenta',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: const Text(
                'Una vez eliminada tu cuenta, no se puede recuperar. Esta acción es irreversible.',
                style: TextStyle(color: _textGrey, height: 1.45),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: _textGrey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Eliminar definitivamente'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      deletingAccount = true;
      securityFeedback = null;
    });

    try {
      await AuthService.deleteAccount();
      await AuthService.logout();

      if (!mounted) return;
      context.go('/login'); // deleteAccount no usa provider porque la cuenta ya no existe
    } catch (e) {
      if (!mounted) return;

      setState(() {
        securityFeedback = e.toString().replaceFirst('Exception: ', '');
        securitySuccess = false;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        deletingAccount = false;
      });
    }
  }

  String get initials {
    final fromNames = [
      if (firstName.trim().isNotEmpty) firstName.trim()[0],
      if (lastName.trim().isNotEmpty) lastName.trim()[0],
    ].join();

    if (fromNames.isNotEmpty) return fromNames.toUpperCase();
    if (email.trim().isNotEmpty) {
      return email.substring(0, email.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'AF';
  }

  @override
  Widget build(BuildContext context) {
    return MainAppShell(
      selectedItem: null,
      eyebrow: '',
      titleWhite: 'Configuración ',
      titlePink: 'de cuenta',
      description:
          'Administra tu información general y la seguridad de tu cuenta.',
      showTopNav: true,
      child: loadingProfile
          ? const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator(color: _pink)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TabButton(
                      label: 'General',
                      selected: activeTab == 'general',
                      onTap: () {
                        setState(() {
                          activeTab = 'general';
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    _TabButton(
                      label: 'Seguridad',
                      selected: activeTab == 'security',
                      onTap: () {
                        setState(() {
                          activeTab = 'security';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (activeTab == 'general') ...[
                  const _SectionLabel(text: 'INFORMACIÓN DE CUENTA'),
                  const SizedBox(height: 12),
                  _CardContainer(
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 110,
                                  height: 110,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0x330B0010),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: _pink,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: _pink,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_outlined,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _FieldBlock(
                                          label: 'NOMBRE',
                                          child: _AppTextField(
                                            value: firstName,
                                            onChanged: (value) {
                                              setState(() {
                                                firstName = value;
                                              });
                                            },
                                            hint: 'Nombre',
                                            icon: Icons.person_outline_rounded,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _FieldBlock(
                                          label: 'APELLIDO',
                                          child: _AppTextField(
                                            value: lastName,
                                            onChanged: (value) {
                                              setState(() {
                                                lastName = value;
                                              });
                                            },
                                            hint: 'Apellido',
                                            icon: Icons.person_outline_rounded,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _FieldBlock(
                                    label: 'CORREO LABORAL',
                                    child: _AppTextField(
                                      value: email,
                                      onChanged: (_) {},
                                      hint: 'Correo',
                                      icon: Icons.mail_outline_rounded,
                                      readOnly: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (generalFeedback != null) ...[
                          const SizedBox(height: 14),
                          _FeedbackBanner(
                            message: generalFeedback!,
                            success: generalSuccess,
                          ),
                        ],
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: savingProfile ? null : saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _pink,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              savingProfile
                                  ? 'Guardando...'
                                  : 'Guardar cambios',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _SectionLabel(text: 'AUTENTICACIÓN DE USUARIO'),
                  const SizedBox(height: 12),
                  _CardContainer(
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0x22E8365D),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.key_rounded,
                            color: _pink,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Correo / Contraseña',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Autenticación local con correo y contraseña',
                                style: TextStyle(
                                  color: _textGrey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x221BC47D),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '● ACTIVO',
                            style: TextStyle(
                              color: Color(0xFF1BC47D),
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (activeTab == 'security') ...[
                  const _SectionLabel(text: 'SEGURIDAD'),
                  const SizedBox(height: 12),
                  _CardContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.sync_alt_rounded,
                              color: _pink,
                              size: 26,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CAMBIAR CONTRASEÑA',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Actualiza tu contraseña para mantener tu cuenta segura',
                                    style: TextStyle(
                                      color: _textGrey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _FieldBlock(
                          label: 'CONTRASEÑA ACTUAL',
                          child: _AppTextField(
                            value: currentPassword,
                            onChanged: (value) {
                              setState(() {
                                currentPassword = value;
                              });
                            },
                            hint: '••••••••',
                            icon: Icons.lock_outline_rounded,
                            obscureText: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _FieldBlock(
                                label: 'NUEVA CONTRASEÑA',
                                child: _AppTextField(
                                  value: newPassword,
                                  onChanged: (value) {
                                    setState(() {
                                      newPassword = value;
                                    });
                                  },
                                  hint: '••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _FieldBlock(
                                label: 'CONFIRMAR CONTRASEÑA',
                                child: _AppTextField(
                                  value: confirmPassword,
                                  onChanged: (value) {
                                    setState(() {
                                      confirmPassword = value;
                                    });
                                  },
                                  hint: '••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (securityFeedback != null) ...[
                          const SizedBox(height: 14),
                          _FeedbackBanner(
                            message: securityFeedback!,
                            success: securitySuccess,
                          ),
                        ],
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: savingPassword ? null : changePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _pink,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              savingPassword
                                  ? 'Actualizando...'
                                  : 'ACTUALIZAR CONTRASEÑA',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _CardContainer(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          color: _pink,
                          size: 30,
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ELIMINAR CUENTA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Elimina permanentemente tu cuenta y todos tus datos asociados.',
                                style: TextStyle(
                                  color: _textGrey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: deletingAccount ? null : deleteAccount,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _pink,
                            side: const BorderSide(color: _pink),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            deletingAccount
                                ? 'Eliminando...'
                                : 'ELIMINAR CUENTA',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0x22E8365D) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? _pink : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _pink : _textGrey,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _textGrey,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.8,
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;

  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _FieldBlock extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldBlock({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _textGrey,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _AppTextField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final bool readOnly;

  const _AppTextField({
    required this.value,
    required this.onChanged,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.readOnly = false,
  });

  @override
  State<_AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<_AppTextField> {
  late final TextEditingController _controller;
  bool _obscure = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _obscure = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant _AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      obscureText: _obscure,
      readOnly: widget.readOnly,
      style: const TextStyle(color: Colors.white),
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: _textGrey),
        prefixIcon: Icon(widget.icon, color: _textGrey),
        suffixIcon: widget.obscureText
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _obscure = !_obscure;
                  });
                },
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _textGrey,
                ),
              )
            : null,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _pink),
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  final String message;
  final bool success;

  const _FeedbackBanner({required this.message, required this.success});

  @override
  Widget build(BuildContext context) {
    final bg = success ? const Color(0x221BC47D) : const Color(0x22E8365D);
    final fg = success ? const Color(0xFF1BC47D) : _pink;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(
            success
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            color: fg,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
