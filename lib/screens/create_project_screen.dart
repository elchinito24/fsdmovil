import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';

const _pink = Color(0xFFE8365D);
const _textGrey = Color(0xFF8E8E93);

class CreateProjectScreen extends StatefulWidget {
  final int? preselectedWorkspaceId;

  const CreateProjectScreen({super.key, this.preselectedWorkspaceId});

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
        if (widget.preselectedWorkspaceId != null &&
            ws.any((w) => w['id'] == widget.preselectedWorkspaceId)) {
          selectedWorkspaceId = widget.preselectedWorkspaceId;
        } else if (workspaces.isNotEmpty) {
          selectedWorkspaceId = workspaces.first['id'];
        }
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
        context.pushReplacement('/editor/$projectId');
      } else {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      final errorStr = '$e'.replaceFirst('Exception: ', '');
      final isConflict = errorStr.toLowerCase().contains('ya existe') ||
          errorStr.toLowerCase().contains('already') ||
          errorStr.toLowerCase().contains('unique');
      final deletedId = isConflict
          ? await ApiService.findInactiveProjectByName(
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
              'Proyecto inactivo',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: Text(
              'Ya existe un proyecto con el nombre "${nameController.text.trim()}" que fue eliminado anteriormente (quedó inactivo). ¿Deseas reactivarlo?',
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
            await ApiService.partialUpdateProject(deletedId, {
              'is_active': true,
              'name': nameController.text.trim(),
              'code': codeController.text.trim(),
              'description': descriptionController.text.trim(),
              'workspace_id': selectedWorkspaceId,
            });
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Proyecto reactivado correctamente')),
            );
            context.pushReplacement('/editor/$deletedId');
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                              context, 'Ingrese nombre del proyecto'),
                        ),
                        const SizedBox(height: 20),

                        _label('Código del Proyecto'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: codeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration(context, 'Ej. SIS-002'),
                        ),
                        const SizedBox(height: 20),

                        _label('Descripción'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: descriptionController,
                          maxLines: 4,
                          style: const TextStyle(color: Colors.white),
                          decoration:
                              _inputDecoration(context, 'Ingrese una descripción'),
                        ),
                        const SizedBox(height: 20),

                        _label('Workspace'),
                        const SizedBox(height: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: selectedWorkspaceId,
                              isExpanded: true,
                              dropdownColor: Theme.of(context).colorScheme.surface,
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
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: selectedTemplateId,
                              isExpanded: true,
                              dropdownColor: Theme.of(context).colorScheme.surface,
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
