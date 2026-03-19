import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';

const _pink = Color(0xFFE8365D);
const _darkBg = Color(0xFF0F1017);
const _cardBg = Color(0xFF191B24);
const _fieldBg = Color(0xFF1E2030);
const _borderColor = Color(0xFF2A2D3A);
const _textGrey = Color(0xFF8E8E93);

class EditorScreen extends StatefulWidget {
  final int projectId;

  const EditorScreen({super.key, required this.projectId});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  String selectedSection = 'portada';
  bool loading = true;
  bool saving = false;
  String? errorMessage;

  Map<String, dynamic>? fullResponse;
  Map<String, dynamic>? srs;

  // PORTADA
  final TextEditingController projectNameController = TextEditingController();
  final TextEditingController versionController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController authorController = TextEditingController();
  final TextEditingController organizationController = TextEditingController();

  // INTRODUCCIÓN
  final TextEditingController purposeController = TextEditingController();
  final TextEditingController scopeController = TextEditingController();
  final TextEditingController overviewController = TextEditingController();
  final TextEditingController referencesController = TextEditingController();
  final TextEditingController definitionsController = TextEditingController();

  // DESCRIPCIÓN GENERAL
  final TextEditingController productPerspectiveController =
      TextEditingController();
  final TextEditingController productFunctionsController =
      TextEditingController();
  final TextEditingController userClassesController = TextEditingController();
  final TextEditingController operatingEnvironmentController =
      TextEditingController();
  final TextEditingController constraintsController = TextEditingController();
  final TextEditingController assumptionsController = TextEditingController();

  // REQUISITOS ESPECÍFICOS
  final TextEditingController externalInterfacesController =
      TextEditingController();
  final TextEditingController functionalRequirementsController =
      TextEditingController();
  final TextEditingController nonFunctionalRequirementsController =
      TextEditingController();
  final TextEditingController businessRulesController = TextEditingController();
  final TextEditingController useCasesController = TextEditingController();

  final List<Map<String, String>> sections = const [
    {'value': 'portada', 'label': '1. Portada'},
    {'value': 'introduccion', 'label': '2. Introducción'},
    {'value': 'descripcion', 'label': '3. Descripción General'},
    {'value': 'requisitos', 'label': '4. Requisitos Específicos'},
  ];

  @override
  void initState() {
    super.initState();
    loadSrs();
  }

  @override
  void dispose() {
    projectNameController.dispose();
    versionController.dispose();
    dateController.dispose();
    authorController.dispose();
    organizationController.dispose();

    purposeController.dispose();
    scopeController.dispose();
    overviewController.dispose();
    referencesController.dispose();
    definitionsController.dispose();

    productPerspectiveController.dispose();
    productFunctionsController.dispose();
    userClassesController.dispose();
    operatingEnvironmentController.dispose();
    constraintsController.dispose();
    assumptionsController.dispose();

    externalInterfacesController.dispose();
    functionalRequirementsController.dispose();
    nonFunctionalRequirementsController.dispose();
    businessRulesController.dispose();
    useCasesController.dispose();

    super.dispose();
  }

  Future<void> loadSrs() async {
    try {
      final data = await ApiService.getProjectSrs(widget.projectId);
      final srsData = Map<String, dynamic>.from(data['srs_data'] ?? {});

      final metadata = Map<String, dynamic>.from(srsData['metadata'] ?? {});
      final introduction = Map<String, dynamic>.from(
        srsData['introduction'] ?? {},
      );
      final overallDescription = Map<String, dynamic>.from(
        srsData['overallDescription'] ?? {},
      );
      final specificRequirements = Map<String, dynamic>.from(
        srsData['specificRequirements'] ?? {},
      );

      // PORTADA
      projectNameController.text = _safeText(metadata['projectName']);
      versionController.text = _safeText(data['version'], fallback: '1.0');
      dateController.text = _safeText(metadata['createdAt']);
      authorController.text = _safeText(metadata['owner']);
      organizationController.text = _safeText(metadata['organization']);

      // INTRODUCCIÓN
      purposeController.text = _safeText(introduction['purpose']);
      scopeController.text = _safeText(introduction['scope']);
      overviewController.text = _safeText(introduction['overview']);
      referencesController.text = _listToMultiline(
        List.from(introduction['references'] ?? []),
      );
      definitionsController.text = _definitionsToText(
        List.from(introduction['definitions'] ?? []),
      );

      // DESCRIPCIÓN GENERAL
      productPerspectiveController.text = _safeText(
        overallDescription['productPerspective'],
      );
      productFunctionsController.text = _safeText(
        overallDescription['productFunctions'],
      );
      userClassesController.text = _userClassesToText(
        List.from(overallDescription['userClasses'] ?? []),
      );
      operatingEnvironmentController.text = _safeText(
        overallDescription['operatingEnvironment'],
      );
      constraintsController.text = _safeText(overallDescription['constraints']);
      assumptionsController.text = _safeText(overallDescription['assumptions']);

      // REQUISITOS ESPECÍFICOS
      externalInterfacesController.text = _safeText(
        specificRequirements['externalInterfaces'],
      );
      functionalRequirementsController.text = _listToMultiline(
        List.from(specificRequirements['functionalRequirements'] ?? []),
      );
      nonFunctionalRequirementsController.text = _listToMultiline(
        List.from(specificRequirements['nonFunctionalRequirements'] ?? []),
      );
      businessRulesController.text = _listToMultiline(
        List.from(specificRequirements['businessRules'] ?? []),
      );
      useCasesController.text = _listToMultiline(
        List.from(specificRequirements['useCases'] ?? []),
      );

      setState(() {
        fullResponse = data;
        srs = srsData;
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

  String _safeText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _listToMultiline(List items) {
    if (items.isEmpty) return '';
    return items.map((e) => e.toString()).join('\n');
  }

  List<String> _multilineToList(String value) {
    return value
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _definitionsToText(List items) {
    if (items.isEmpty) return '';
    return items
        .map((item) {
          final data = Map<String, dynamic>.from(item);
          final term = _safeText(data['term']);
          final definition = _safeText(data['definition']);
          return '$term: $definition';
        })
        .join('\n');
  }

  List<Map<String, dynamic>> _textToDefinitions(String value) {
    final lines = value
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return lines.map((line) {
      final parts = line.split(':');
      if (parts.length >= 2) {
        final term = parts.first.trim();
        final definition = parts.sublist(1).join(':').trim();
        return {'term': term, 'definition': definition};
      }
      return {'term': line, 'definition': ''};
    }).toList();
  }

  String _userClassesToText(List items) {
    if (items.isEmpty) return '';
    return items
        .map((item) {
          final data = Map<String, dynamic>.from(item);
          final id = _safeText(data['id']);
          final name = _safeText(data['name']);
          final description = _safeText(data['description']);
          final characteristics = _safeText(data['characteristics']);
          return '$id | $name | $description | $characteristics';
        })
        .join('\n');
  }

  List<Map<String, dynamic>> _textToUserClasses(String value) {
    final lines = value
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return lines.map((line) {
      final parts = line.split('|').map((e) => e.trim()).toList();
      return {
        'id': parts.isNotEmpty ? parts[0] : '',
        'name': parts.length > 1 ? parts[1] : '',
        'description': parts.length > 2 ? parts[2] : '',
        'characteristics': parts.length > 3 ? parts[3] : '',
      };
    }).toList();
  }

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textGrey),
      filled: true,
      fillColor: _fieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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

  Widget buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: Colors.white,
      ),
    );
  }

  Widget buildSingleField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildFieldLabel(label),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: inputDecoration(hint),
        ),
      ],
    );
  }

  Future<void> saveChanges() async {
    if (srs == null || fullResponse == null) return;

    try {
      setState(() {
        saving = true;
      });

      final updatedSrs = Map<String, dynamic>.from(srs!);

      // PORTADA
      final metadata = Map<String, dynamic>.from(updatedSrs['metadata'] ?? {});
      metadata['projectName'] = projectNameController.text.trim();
      metadata['createdAt'] = dateController.text.trim();
      metadata['owner'] = authorController.text.trim();
      metadata['organization'] = organizationController.text.trim();
      updatedSrs['metadata'] = metadata;

      // INTRODUCCIÓN
      final introduction = Map<String, dynamic>.from(
        updatedSrs['introduction'] ?? {},
      );
      introduction['purpose'] = purposeController.text.trim();
      introduction['scope'] = scopeController.text.trim();
      introduction['overview'] = overviewController.text.trim();
      introduction['references'] = _multilineToList(
        referencesController.text.trim(),
      );
      introduction['definitions'] = _textToDefinitions(
        definitionsController.text.trim(),
      );
      updatedSrs['introduction'] = introduction;

      // DESCRIPCIÓN GENERAL
      final overallDescription = Map<String, dynamic>.from(
        updatedSrs['overallDescription'] ?? {},
      );
      overallDescription['productPerspective'] = productPerspectiveController
          .text
          .trim();
      overallDescription['productFunctions'] = productFunctionsController.text
          .trim();
      overallDescription['userClasses'] = _textToUserClasses(
        userClassesController.text.trim(),
      );
      overallDescription['operatingEnvironment'] =
          operatingEnvironmentController.text.trim();
      overallDescription['constraints'] = constraintsController.text.trim();
      overallDescription['assumptions'] = assumptionsController.text.trim();
      updatedSrs['overallDescription'] = overallDescription;

      // REQUISITOS ESPECÍFICOS
      final specificRequirements = Map<String, dynamic>.from(
        updatedSrs['specificRequirements'] ?? {},
      );
      specificRequirements['externalInterfaces'] = externalInterfacesController
          .text
          .trim();
      specificRequirements['functionalRequirements'] = _multilineToList(
        functionalRequirementsController.text.trim(),
      );
      specificRequirements['nonFunctionalRequirements'] = _multilineToList(
        nonFunctionalRequirementsController.text.trim(),
      );
      specificRequirements['businessRules'] = _multilineToList(
        businessRulesController.text.trim(),
      );
      specificRequirements['useCases'] = _multilineToList(
        useCasesController.text.trim(),
      );
      updatedSrs['specificRequirements'] = specificRequirements;

      final body = {
        'project_id': fullResponse!['project_id'],
        'project_code': fullResponse!['project_code'],
        'version': versionController.text.trim().isEmpty
            ? '1.0'
            : versionController.text.trim(),
        'srs_data': updatedSrs,
      };

      await ApiService.updateProjectSrs(widget.projectId, body);

      setState(() {
        srs = updatedSrs;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cambios guardados correctamente')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Widget buildPortadaFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSingleField(
          label: 'Nombre del Proyecto',
          controller: projectNameController,
          hint: 'Ingrese nombre del proyecto',
        ),
        const SizedBox(height: 18),
        buildSingleField(
          label: 'Versión',
          controller: versionController,
          hint: 'Ingrese versión',
        ),
        const SizedBox(height: 18),
        buildSingleField(
          label: 'Fecha',
          controller: dateController,
          hint: 'dd/mm/aaaa',
        ),
        const SizedBox(height: 18),
        buildSingleField(
          label: 'Autor(es)',
          controller: authorController,
          hint: 'Ingrese autor(es)',
        ),
        const SizedBox(height: 18),
        buildSingleField(
          label: 'Organización',
          controller: organizationController,
          hint: 'Ingrese organización',
        ),
      ],
    );
  }

  Widget buildIntroduccionFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSingleField(
          label: 'Propósito',
          controller: purposeController,
          hint: 'Ingrese el propósito',
          maxLines: 4,
        ),
        const SizedBox(height: 18),
        buildSingleField(
          label: 'Alcance',
          controller: scopeController,
          hint: 'Ingrese el alcance',
          maxLines: 4,
        ),
        const SizedBox(height: 18),
        buildSingleField(
          label: 'Visión General',
          controller: overviewController,
          hint: 'Ingrese la visión general',
          maxLines: 4,
        ),
        const SizedBox(height: 18),
        buildSingleField(
          label: 'Referencias',
          controller: referencesController,
          hint: 'Una referencia por línea',
          maxLines: 5,
        ),
        const SizedBox(height: 18),
        buildSingleField(
          label: 'Definiciones, Acrónimos y Abreviaturas',
          controller: definitionsController,
          hint: 'Formato: Término: Definición',
          maxLines: 6,
        ),
      ],
    );
  }

  Widget buildDescripcionFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSingleField(
          label: 'Perspectiva del Producto',
          controller: productPerspectiveController,
          hint: 'Ingrese la perspectiva del producto',
          maxLines: 4,
        ),
        const SizedBox(height: 18),
        buildSingleField(
          label: 'Funciones del Producto',
          controller: productFunctionsController,
          hint: 'Ingrese las funciones del producto',
          maxLines: 5,
        ),
        const SizedBox(height: 18),
        buildSingleField(
          label: 'Clases de Usuario',
          controller: userClassesController,
          hint: 'Formato: ID | Nombre | Descripción | Características',
          maxLines: 6,
        ),
        const SizedBox(height: 18),
        buildSingleField(
          label: 'Entorno Operativo',
          controller: operatingEnvironmentController,
          hint: 'Ingrese el entorno operativo',
          maxLines: 4,
        ),
        const SizedBox(height: 18),
        buildSingleField(
          label: 'Restricciones',
          controller: constraintsController,
          hint: 'Ingrese las restricciones',
          maxLines: 4,
        ),
        const SizedBox(height: 18),
        buildSingleField(
          label: 'Suposiciones y Dependencias',
          controller: assumptionsController,
          hint: 'Ingrese las suposiciones y dependencias',
          maxLines: 4,
        ),
      ],
    );
  }

  Widget buildRequisitosFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSingleField(
          label: 'Interfaces Externas',
          controller: externalInterfacesController,
          hint: 'Ingrese las interfaces externas',
          maxLines: 4,
        ),
        const SizedBox(height: 18),
        buildSingleField(
          label: 'Requisitos Funcionales',
          controller: functionalRequirementsController,
          hint: 'Un requisito por línea',
          maxLines: 6,
        ),
        const SizedBox(height: 18),
        buildSingleField(
          label: 'Requisitos No Funcionales',
          controller: nonFunctionalRequirementsController,
          hint: 'Un requisito por línea',
          maxLines: 6,
        ),
        const SizedBox(height: 18),
        buildSingleField(
          label: 'Reglas de Negocio',
          controller: businessRulesController,
          hint: 'Una regla por línea',
          maxLines: 5,
        ),
        const SizedBox(height: 18),
        buildSingleField(
          label: 'Casos de Uso',
          controller: useCasesController,
          hint: 'Un caso de uso por línea',
          maxLines: 5,
        ),
      ],
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
          'Editor IEEE 830',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  context.push('/preview/${widget.projectId}');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _pink,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.remove_red_eye_outlined,
                        size: 17,
                        color: Colors.white,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Previa',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: _pink),
              )
            : errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: _pink, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _textGrey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            loading = true;
                            errorMessage = null;
                          });
                          loadSrs();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            : SafeArea(
                top: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                  children: [
                    const Text(
                      'Seleccionar Sección',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: _fieldBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedSection,
                          isExpanded: true,
                          dropdownColor: _cardBg,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: _textGrey,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          items: sections.map((section) {
                            return DropdownMenuItem<String>(
                              value: section['value'],
                              child: Text(section['label']!),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              selectedSection = value;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (selectedSection == 'portada') buildPortadaFields(),
                    if (selectedSection == 'introduccion')
                      buildIntroduccionFields(),
                    if (selectedSection == 'descripcion')
                      buildDescripcionFields(),
                    if (selectedSection == 'requisitos')
                      buildRequisitosFields(),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: saving ? null : saveChanges,
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
                                'Guardar cambios',
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
