import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';

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

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9A9A9A)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE8365D), width: 1.5),
      ),
    );
  }

  Widget buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: Colors.black,
      ),
    );
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
      setState(() {
        saving = true;
      });

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al crear workspace: $e')));
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF06071B),
        foregroundColor: Colors.white,
        title: const Text(
          'Crear Workspace',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          buildLabel('Nombre del Workspace'),
          const SizedBox(height: 10),
          TextField(
            controller: nameController,
            decoration: inputDecoration('Ingrese nombre del workspace'),
            onChanged: (value) {
              final newSlug = generateSlug(value);
              slugController.text = newSlug;
              slugController.selection = TextSelection.fromPosition(
                TextPosition(offset: slugController.text.length),
              );
            },
          ),
          const SizedBox(height: 18),
          buildLabel('Slug'),
          const SizedBox(height: 10),
          TextField(
            controller: slugController,
            decoration: inputDecoration('ejemplo-workspace'),
          ),
          const SizedBox(height: 18),
          buildLabel('Descripción'),
          const SizedBox(height: 10),
          TextField(
            controller: descriptionController,
            maxLines: 4,
            decoration: inputDecoration('Ingrese una descripción'),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: saving ? null : saveWorkspace,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8365D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
    );
  }
}
