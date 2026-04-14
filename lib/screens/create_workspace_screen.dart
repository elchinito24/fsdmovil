import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';

const _pink = Color(0xFFE8365D);
const _textGrey = Color(0xFF8E8E93);

class CreateWorkspaceScreen extends StatefulWidget {
  const CreateWorkspaceScreen({super.key});

  @override
  State<CreateWorkspaceScreen> createState() => _CreateWorkspaceScreenState();
}

class _CreateWorkspaceScreenState extends State<CreateWorkspaceScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController slugController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  bool saving = false;

  @override
  void dispose() {
    nameController.dispose();
    slugController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  String generateSlug(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
  }

  Future<void> saveWorkspace() async {
    if (nameController.text.trim().isEmpty ||
        slugController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre y slug son obligatorios')),
      );
      return;
    }

    try {
      setState(() => saving = true);

      final body = {
        'name': nameController.text.trim(),
        'slug': slugController.text.trim(),
        'description': descriptionController.text.trim(),
      };

      await ApiService.createWorkspace(body);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace creado correctamente')),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      final errorStr = '$e'.replaceFirst('Exception: ', '');
      final isConflict = errorStr.toLowerCase().contains('ya existe') ||
          errorStr.toLowerCase().contains('already') ||
          errorStr.toLowerCase().contains('unique');
      final deletedId = isConflict
          ? await ApiService.findInactiveWorkspaceByName(
              nameController.text.trim())
          : null;

      if (deletedId != null) {
        final reactivate = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Workspace inactivo',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: Text(
              'Ya existe un workspace con el nombre "${nameController.text.trim()}" que fue eliminado anteriormente (quedó inactivo). ¿Deseas reactivarlo?',
              style: const TextStyle(color: _textGrey, height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar',
                    style: TextStyle(color: _textGrey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Reactivar'),
              ),
            ],
          ),
        );

        if (reactivate == true && mounted) {
          try {
            await ApiService.partialUpdateWorkspace(deletedId, {
              'is_active': true,
              'name': nameController.text.trim(),
              'slug': slugController.text.trim(),
              'description': descriptionController.text.trim(),
            });
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Workspace reactivado correctamente')),
            );
            context.pop(true);
          } catch (reactivateErr) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('$reactivateErr'
                      .replaceFirst('Exception: ', ''))),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorStr)),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  InputDecoration _inputDecoration(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textGrey),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _pink, width: 1.5),
      ),
    );
  }

  Widget _label(String text) {
    return Builder(
      builder: (context) => Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: Text(
          'Crear Workspace',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.85, 0.85),
            radius: 0.9,
            colors: [Color(0x1FE8365D), Colors.transparent],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            children: [
              const Text(
                'NUEVO',
                style: TextStyle(
                  color: _pink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Crear ',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 38,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const TextSpan(
                      text: 'Workspace',
                      style: TextStyle(
                        color: _pink,
                        fontSize: 38,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Organiza equipos y proyectos dentro de un nuevo workspace.',
                style:
                    TextStyle(color: _textGrey, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),

              _label('Nombre del Workspace'),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration:
                    _inputDecoration(context, 'Ingrese nombre del workspace'),
                onChanged: (value) {
                  final newSlug = generateSlug(value);
                  slugController.text = newSlug;
                  slugController.selection = TextSelection.fromPosition(
                    TextPosition(offset: slugController.text.length),
                  );
                },
              ),
              const SizedBox(height: 20),

              _label('Slug'),
              const SizedBox(height: 8),
              TextField(
                controller: slugController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: _inputDecoration(context, 'ejemplo-workspace'),
              ),
              const SizedBox(height: 20),

              _label('Descripción'),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                maxLines: 4,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: _inputDecoration(context, 'Ingrese una descripción'),
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: saving ? null : saveWorkspace,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _pink.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Crear Workspace',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
