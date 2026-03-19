import 'package:flutter/material.dart';
import 'package:fsdmovil/services/api_service.dart';

class PreviewScreen extends StatefulWidget {
  final int projectId;

  const PreviewScreen({super.key, required this.projectId});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool loading = true;
  String? errorMessage;
  Map<String, dynamic>? responseData;

  @override
  void initState() {
    super.initState();
    loadPreview();
  }

  Future<void> loadPreview() async {
    try {
      final data = await ApiService.getProjectSrs(widget.projectId);

      setState(() {
        responseData = data;
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

  String safeText(dynamic value, {String fallback = 'Sin información'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  Widget buildActionButton({
    required String text,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: SizedBox(
        height: 50,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.download, size: 18),
          label: Text(text),
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: textColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  static Widget _centerInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 15, color: Colors.black),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  static Widget _documentSubTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Colors.black,
      ),
    );
  }

  static Widget _documentParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSimpleList(List items, {String emptyText = 'Sin información'}) {
    if (items.isEmpty) {
      return _documentParagraph(emptyText);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '• ${safeText(item)}',
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDefinitionsList(List items) {
    if (items.isEmpty) {
      return _documentParagraph('Sin información');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final data = Map<String, dynamic>.from(item);
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${safeText(data['term'])}: ${safeText(data['definition'])}',
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUserClasses(List items) {
    if (items.isEmpty) {
      return _documentParagraph('Sin clases de usuario registradas');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final data = Map<String, dynamic>.from(item);
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• ${safeText(data['name'], fallback: 'Usuario')}',
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (safeText(data['id'], fallback: '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'ID: ${safeText(data['id'])}',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Descripción: ${safeText(data['description'])}',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Características: ${safeText(data['characteristics'])}',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget buildDocumentPreview() {
    final srs = Map<String, dynamic>.from(responseData?['srs_data'] ?? {});
    final metadata = Map<String, dynamic>.from(srs['metadata'] ?? {});
    final introduction = Map<String, dynamic>.from(srs['introduction'] ?? {});
    final overallDescription = Map<String, dynamic>.from(
      srs['overallDescription'] ?? {},
    );
    final specificRequirements = Map<String, dynamic>.from(
      srs['specificRequirements'] ?? {},
    );

    final projectName = safeText(metadata['projectName']);
    final version = safeText(responseData?['version'], fallback: '1.0');
    final date = safeText(metadata['createdAt']);
    final author = safeText(metadata['owner']);
    final organization = safeText(metadata['organization']);

    final purpose = safeText(introduction['purpose']);
    final scope = safeText(introduction['scope']);
    final overview = safeText(introduction['overview']);
    final references = List.from(introduction['references'] ?? []);
    final definitions = List.from(introduction['definitions'] ?? []);

    final productPerspective = safeText(
      overallDescription['productPerspective'],
    );
    final productFunctions = safeText(overallDescription['productFunctions']);
    final userClasses = List.from(overallDescription['userClasses'] ?? []);
    final operatingEnvironment = safeText(
      overallDescription['operatingEnvironment'],
    );
    final constraints = safeText(overallDescription['constraints']);
    final assumptions = safeText(overallDescription['assumptions']);

    final externalInterfaces = safeText(
      specificRequirements['externalInterfaces'],
    );
    final functionalRequirements = List.from(
      specificRequirements['functionalRequirements'] ?? [],
    );
    final nonFunctionalRequirements = List.from(
      specificRequirements['nonFunctionalRequirements'] ?? [],
    );
    final businessRules = List.from(
      specificRequirements['businessRules'] ?? [],
    );
    final useCases = List.from(specificRequirements['useCases'] ?? []);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Icon(
              Icons.description_outlined,
              size: 56,
              color: Color(0xFF9AA3AF),
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'Especificación de Requisitos de Software',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Column(
              children: [
                _centerInfoRow('Proyecto', projectName),
                _centerInfoRow('Versión', version),
                _centerInfoRow('Fecha', date),
                _centerInfoRow('Autor', author),
                _centerInfoRow('Organización', organization),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Divider(height: 1),
          const SizedBox(height: 26),

          const Text(
            '1. Introducción',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 18),

          _documentSubTitle('1.1 Propósito'),
          _documentParagraph(purpose),

          const SizedBox(height: 18),
          _documentSubTitle('1.2 Alcance'),
          _documentParagraph(scope),

          const SizedBox(height: 18),
          _documentSubTitle('1.3 Definiciones, Acrónimos y Abreviaturas'),
          _buildDefinitionsList(definitions),

          const SizedBox(height: 18),
          _documentSubTitle('1.4 Referencias'),
          _buildSimpleList(
            references,
            emptyText: 'Sin referencias registradas',
          ),

          const SizedBox(height: 18),
          _documentSubTitle('1.5 Visión General'),
          _documentParagraph(overview),

          const SizedBox(height: 28),
          const Text(
            '2. Descripción General',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 18),

          _documentSubTitle('2.1 Perspectiva del Producto'),
          _documentParagraph(productPerspective),

          const SizedBox(height: 18),
          _documentSubTitle('2.2 Funciones del Producto'),
          _documentParagraph(productFunctions),

          const SizedBox(height: 18),
          _documentSubTitle('2.3 Clases de Usuario'),
          _buildUserClasses(userClasses),

          const SizedBox(height: 18),
          _documentSubTitle('2.4 Entorno Operativo'),
          _documentParagraph(operatingEnvironment),

          const SizedBox(height: 18),
          _documentSubTitle('2.5 Restricciones'),
          _documentParagraph(constraints),

          const SizedBox(height: 18),
          _documentSubTitle('2.6 Suposiciones y Dependencias'),
          _documentParagraph(assumptions),

          const SizedBox(height: 28),
          const Text(
            '3. Requisitos Específicos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 18),

          _documentSubTitle('3.1 Interfaces Externas'),
          _documentParagraph(externalInterfaces),

          const SizedBox(height: 18),
          _documentSubTitle('3.2 Requisitos Funcionales'),
          _buildSimpleList(
            functionalRequirements,
            emptyText: 'Sin requisitos funcionales registrados',
          ),

          const SizedBox(height: 18),
          _documentSubTitle('3.3 Requisitos No Funcionales'),
          _buildSimpleList(
            nonFunctionalRequirements,
            emptyText: 'Sin requisitos no funcionales registrados',
          ),

          const SizedBox(height: 18),
          _documentSubTitle('3.4 Reglas de Negocio'),
          _buildSimpleList(
            businessRules,
            emptyText: 'Sin reglas de negocio registradas',
          ),

          const SizedBox(height: 18),
          _documentSubTitle('3.5 Casos de Uso'),
          _buildSimpleList(useCases, emptyText: 'Sin casos de uso registrados'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF06071B),
        foregroundColor: Colors.white,
        title: const Text(
          'Vista Previa',
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
                Row(
                  children: [
                    buildActionButton(
                      text: 'PDF',
                      backgroundColor: const Color(0xFFE21B4B),
                      textColor: Colors.white,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'La descarga de PDF quedará pendiente por ahora',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 14),
                    buildActionButton(
                      text: 'Word',
                      backgroundColor: const Color(0xFF06071B),
                      textColor: Colors.white,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'La descarga de Word quedará pendiente por ahora',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                buildDocumentPreview(),
              ],
            ),
    );
  }
}
