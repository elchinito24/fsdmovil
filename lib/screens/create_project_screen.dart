import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';

const _pink = Color(0xFFE8365D);
const _darkBg = Color(0xFF0F1017);
const _cardBg = Color(0xFF191B24);
const _fieldBg = Color(0xFF1E2030);
const _borderColor = Color(0xFF2A2D3A);
const _textGrey = Color(0xFF8E8E93);

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
        if (workspaces.isNotEmpty) selectedWorkspaceId = workspaces.first['id'];
        if (templates.isNotEmpty) selectedTemplateId = templates.first['id'];
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
      setState(() => saving = true);

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear proyecto: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textGrey),
      filled: true,
      fillColor: _fieldBg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _pink, width: 1.5),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Crear Proyecto',
          style: TextStyle(fontWeight: FontWeight.w800),
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
          child: loading
              ? const Center(child: CircularProgressIndicator(color: _pink))
              : errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: _borderColor),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: _pink, size: 42),
                              const SizedBox(height: 12),
                              Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: _textGrey, fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() => loading = true);
                                  loadInitialData();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _pink,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      padding:
                          const EdgeInsets.fromLTRB(20, 10, 20, 40),
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
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Crear ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  height: 1.05,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              TextSpan(
                                text: 'Proyecto',
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
                          'Completa los datos para iniciar tu documento SRS.',
                          style: TextStyle(
                              color: _textGrey, fontSize: 14, height: 1.5),
                        ),
                        const SizedBox(height: 32),

                        _label('Nombre del Proyecto'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration(
                              'Ingrese nombre del proyecto'),
                        ),
                        const SizedBox(height: 20),

                        _label('Código del Proyecto'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: codeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Ej. SIS-002'),
                        ),
                        const SizedBox(height: 20),

                        _label('Descripción'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: descriptionController,
                          maxLines: 4,
                          style: const TextStyle(color: Colors.white),
                          decoration:
                              _inputDecoration('Ingrese una descripción'),
                        ),
                        const SizedBox(height: 20),

                        _label('Workspace'),
                        const SizedBox(height: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: _fieldBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: selectedWorkspaceId,
                              isExpanded: true,
                              dropdownColor: _cardBg,
                              style: const TextStyle(color: Colors.white),
                              iconEnabledColor: _textGrey,
                              items: workspaces.map((ws) {
                                return DropdownMenuItem<int>(
                                  value: ws['id'] as int,
                                  child: Text(ws['name'] ?? 'Workspace'),
                                );
                              }).toList(),
                              onChanged: (value) =>
                                  setState(() => selectedWorkspaceId = value),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        _label('Plantilla'),
                        const SizedBox(height: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: _fieldBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: selectedTemplateId,
                              isExpanded: true,
                              dropdownColor: _cardBg,
                              style: const TextStyle(color: Colors.white),
                              iconEnabledColor: _textGrey,
                              items: templates.map((tpl) {
                                return DropdownMenuItem<int>(
                                  value: tpl['id'] as int,
                                  child: Text(tpl['name'] ?? 'Template'),
                                );
                              }).toList(),
                              onChanged: (value) =>
                                  setState(() => selectedTemplateId = value),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: saving ? null : saveProject,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _pink,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  _pink.withOpacity(0.5),
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
        ),
      ),
    );
  }
}
