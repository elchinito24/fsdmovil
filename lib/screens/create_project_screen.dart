import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  bool loading = true;
  bool saving = false;
  String? errorMessage;

  List<dynamic> workspaces = [];
  List<dynamic> templates = [];

  int? selectedWorkspaceId;
  int? selectedTemplateId;

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> loadInitialData() async {
    try {
      final ws = await ApiService.getWorkspaces();
      final tpl = await ApiService.getTemplates();

      setState(() {
        workspaces = ws;
        templates = tpl;

        if (workspaces.isNotEmpty) {
          selectedWorkspaceId = workspaces.first['id'];
        }

        if (templates.isNotEmpty) {
          selectedTemplateId = templates.first['id'];
        }

        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    }
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

  Future<void> saveProject() async {
    if (nameController.text.trim().isEmpty ||
        codeController.text.trim().isEmpty ||
        selectedWorkspaceId == null ||
        selectedTemplateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos obligatorios')),
      );
      return;
    }

    try {
      setState(() {
        saving = true;
      });

      final body = {
        'name': nameController.text.trim(),
        'code': codeController.text.trim(),
        'description': descriptionController.text.trim(),
        'workspace_id': selectedWorkspaceId,
        'template_id': selectedTemplateId,
      };

      final createdProject = await ApiService.createProject(body);
      final projectId = createdProject['id'];

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proyecto creado correctamente')),
      );

      if (projectId != null) {
        context.go('/editor/$projectId');
      } else {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al crear proyecto: $e')));
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
          'Crear Proyecto',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(errorMessage!, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                buildLabel('Nombre del Proyecto'),
                const SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  decoration: inputDecoration('Ingrese nombre del proyecto'),
                ),
                const SizedBox(height: 18),
                buildLabel('Código del Proyecto'),
                const SizedBox(height: 10),
                TextField(
                  controller: codeController,
                  decoration: inputDecoration('Ej. SIS-002'),
                ),
                const SizedBox(height: 18),
                buildLabel('Descripción'),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: inputDecoration('Ingrese una descripción'),
                ),
                const SizedBox(height: 18),
                buildLabel('Workspace'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD9D9D9)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedWorkspaceId,
                      isExpanded: true,
                      items: workspaces.map((workspace) {
                        return DropdownMenuItem<int>(
                          value: workspace['id'] as int,
                          child: Text(workspace['name'] ?? 'Workspace'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedWorkspaceId = value;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                buildLabel('Plantilla'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD9D9D9)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedTemplateId,
                      isExpanded: true,
                      items: templates.map((template) {
                        return DropdownMenuItem<int>(
                          value: template['id'] as int,
                          child: Text(template['name'] ?? 'Template'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedTemplateId = value;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: saving ? null : saveProject,
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
                            'Crear Proyecto',
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
