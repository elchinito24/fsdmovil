import 'package:flutter/material.dart';
import 'dart:math';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/services/srs_word_service.dart';

const _pink = Color(0xFFE8365D);
const _darkBg = Color(0xFF0F1017);
const _textGrey = Color(0xFF8E8E93);

// Word document colors
const _docBg = Colors.white;
const _docText = Color(0xFF1A1A1A);
const _docTextLight = Color(0xFF444444);
const _docHeading1 = Color(0xFF1F3864); // Word navy blue
const _docHeading2 = Color(0xFF2E5197);
const _docAccent = Color(0xFF2E5197);
const _docBorder = Color(0xFFD0D7DE);
const _docTableHeader = Color(0xFFD6E4F0);

class PreviewScreen extends StatefulWidget {
  final int projectId;

  const PreviewScreen({super.key, required this.projectId});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool loading = true;
  bool _generatingWord = false;
  String? errorMessage;
  Map<String, dynamic>? responseData;

  final TransformationController _transformController =
      TransformationController();
  bool _transformSet = false;
  double _fitScale = 0.01;

  @override
  void initState() {
    super.initState();
    loadPreview();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    const docWidth = 794.0;
    const docHeight = 1123.0;
    final screenSize = MediaQuery.of(context).size;
    final scaleX = screenSize.width / docWidth;
    final scaleY = screenSize.height / docHeight;
    // Use the larger scale so the page always fills at least one axis and
    // cannot be zoomed out smaller than the device (prevents the sheet
    // from becoming visually tiny).
    // Fit scale ensures the whole page fits into the viewport. No margin.
    // Add a fixed 4px margin around the page at min zoom
    final marginPx = 4.0;
    final fitScale = min(
      (screenSize.width - marginPx * 2) / docWidth,
      (screenSize.height - marginPx * 2) / docHeight,
    );
    final newFitScale = fitScale;
    if ((newFitScale - _fitScale).abs() > 0.001) {
      _fitScale = newFitScale;
      if (!_transformSet) {
        _transformSet = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Always apply a fixed 4px margin on all sides
            final scale = _fitScale;
            final marginPx = 4.0;
            final offsetX = marginPx / scale;
            final offsetY = marginPx / scale;
            _transformController.value = Matrix4.identity()
              ..translate(offsetX, offsetY)
              ..scale(scale, scale, 1);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
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

  // ---------- Word-style document widgets ----------

  Widget _docH1(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _docHeading1,
            letterSpacing: 0.2,
          ),
        ),
      );

  Widget _docH2(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _docHeading2,
          ),
        ),
      );

  Widget _docP(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            height: 1.7,
            color: _docTextLight,
          ),
        ),
      );

  Widget _docBulletList(List items, {String emptyText = 'Sin información'}) {
    if (items.isEmpty) return _docP(emptyText);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 4, left: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: CircleAvatar(
                      radius: 3,
                      backgroundColor: _docAccent,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      safeText(item),
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.7,
                        color: _docTextLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _docDefinitionsList(List items) {
    if (items.isEmpty) return _docP('Sin información');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final data = Map<String, dynamic>.from(item);
        final term = safeText(data['term'], fallback: '');
        final def = safeText(data['definition'], fallback: '');
        return Padding(
          padding: const EdgeInsets.only(top: 6, left: 8),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
                height: 1.7,
                color: _docTextLight,
              ),
              children: [
                TextSpan(
                  text: '$term: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _docText,
                  ),
                ),
                TextSpan(text: def),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _docUserClasses(List items) {
    if (items.isEmpty) return _docP('Sin clases de usuario registradas');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final data = Map<String, dynamic>.from(item);
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F8FF),
            border: Border.all(color: _docBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                safeText(data['name'], fallback: 'Usuario'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _docText,
                ),
              ),
              if (safeText(data['id'], fallback: '').isNotEmpty)
                _docFieldRow('ID', safeText(data['id'])),
              _docFieldRow('Descripción', safeText(data['description'])),
              _docFieldRow(
                'Características',
                safeText(data['characteristics']),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _docFieldRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 12, height: 1.5, color: _docTextLight),
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _docText,
                ),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      );

  Widget _docDivider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Divider(color: _docBorder, thickness: 1),
      );

  Widget _docInfoTable({
    required String projectName,
    required String version,
    required String date,
    required String author,
    required String organization,
  }) {
    final rows = [
      ['Proyecto', projectName],
      ['Versión', version],
      ['Fecha', date],
      ['Autor(es)', author],
      ['Organización', organization],
    ];
    return Table(
      border: TableBorder.all(color: _docBorder, width: 0.8),
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
      },
      children: rows.map((row) {
        return TableRow(
          decoration: BoxDecoration(
            color: row == rows.first ? _docTableHeader : Colors.white,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text(
                row[0],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _docText,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text(
                row[1],
                style: const TextStyle(fontSize: 12, color: _docTextLight),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDocumentPage() {
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

    final pages = <(String, List<Widget>)>[
      (
        '1',
        [
          // ── PORTADA ──────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(width: 56, height: 6, color: _docHeading1),
                const SizedBox(height: 20),
                const Text(
                  'ESPECIFICACIÓN DE\nREQUISITOS DE SOFTWARE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _docHeading1,
                    letterSpacing: 1,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'IEEE Std 830',
                  style: TextStyle(
                    fontSize: 12,
                    color: _docAccent,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
          _docInfoTable(
            projectName: projectName,
            version: version,
            date: date,
            author: author,
            organization: organization,
          ),
        ],
      ),
      (
        '2',
        [
          // ── 1. INTRODUCCIÓN ──────────────────────────
          _docH1('1. Introducción'),
          _docH2('1.1 Propósito'),
          _docP(safeText(introduction['purpose'])),
          _docH2('1.2 Alcance'),
          _docP(safeText(introduction['scope'])),
          _docH2('1.3 Definiciones, Acrónimos y Abreviaturas'),
          _docDefinitionsList(List.from(introduction['definitions'] ?? [])),
          _docH2('1.4 Referencias'),
          _docBulletList(
            List.from(introduction['references'] ?? []),
            emptyText: 'Sin referencias registradas',
          ),
          _docH2('1.5 Visión General'),
          _docP(safeText(introduction['overview'])),
        ],
      ),
      (
        '3',
        [
          // ── 2. DESCRIPCIÓN GENERAL ───────────────────
          _docH1('2. Descripción General'),
          _docH2('2.1 Perspectiva del Producto'),
          _docP(safeText(overallDescription['productPerspective'])),
          _docH2('2.2 Funciones del Producto'),
          _docP(safeText(overallDescription['productFunctions'])),
          _docH2('2.3 Clases de Usuario'),
          _docUserClasses(List.from(overallDescription['userClasses'] ?? [])),
          _docH2('2.4 Entorno Operativo'),
          _docP(safeText(overallDescription['operatingEnvironment'])),
          _docH2('2.5 Restricciones'),
          _docP(safeText(overallDescription['constraints'])),
          _docH2('2.6 Suposiciones y Dependencias'),
          _docP(safeText(overallDescription['assumptions'])),
        ],
      ),
      (
        '4',
        [
          // ── 3. REQUISITOS ESPECÍFICOS ────────────────
          _docH1('3. Requisitos Específicos'),
          _docH2('3.1 Interfaces Externas'),
          _docP(safeText(specificRequirements['externalInterfaces'])),
          _docH2('3.2 Requisitos Funcionales'),
          _docBulletList(
            List.from(specificRequirements['functionalRequirements'] ?? []),
            emptyText: 'Sin requisitos funcionales registrados',
          ),
          _docH2('3.3 Requisitos No Funcionales'),
          _docBulletList(
            List.from(
                specificRequirements['nonFunctionalRequirements'] ?? []),
            emptyText: 'Sin requisitos no funcionales registrados',
          ),
          _docH2('3.4 Reglas de Negocio'),
          _docBulletList(
            List.from(specificRequirements['businessRules'] ?? []),
            emptyText: 'Sin reglas de negocio registradas',
          ),
          _docH2('3.5 Casos de Uso'),
          _docBulletList(
            List.from(specificRequirements['useCases'] ?? []),
            emptyText: 'Sin casos de uso registrados',
          ),
          const SizedBox(height: 16),
          _docDivider(),
          Center(
            child: Text(
              'Documento generado por FSD  •  v$version',
              style: const TextStyle(fontSize: 11, color: _textGrey),
            ),
          ),
        ],
      ),
    ];

    return Column(
      children: pages.map((entry) {
        final pageNum = entry.$1;
        final content = entry.$2;
        return Column(
          children: [
            // número de página encima
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Página $pageNum',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.40),
                  fontSize: 11,
                ),
              ),
            ),
            // hoja blanca A4 (794 × 1123 @ 96dpi)
            SizedBox(
              width: 794,
              height: 1123,
              child: Container(
                decoration: BoxDecoration(
                  color: _docBg,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.40),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(height: 5, color: const Color(0xFF2B579A)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(96, 48, 96, 0),
                        child: ClipRect(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: content,
                          ),
                        ),
                      ),
                    ),
                    // pie de página con número
                    Container(
                      height: 32,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: _docBorder, width: 0.8),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$pageNum',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _docTextLight,
                        ),
                      ),
                  ),
                ],
              ),
            ),
            ),
            // espacio entre hojas (simula el fondogris entre páginas)
            if (pageNum != '4') const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildWordViewer() {
    final srs = Map<String, dynamic>.from(responseData?['srs_data'] ?? {});
    final metadata = Map<String, dynamic>.from(srs['metadata'] ?? {});
    final projectName = safeText(metadata['projectName'], fallback: 'Documento');
    final version = safeText(responseData?['version'], fallback: '1.0');
    final safeName = projectName.replaceAll(' ', '_');

    return Column(
      children: [
        // ── Word-style document title bar ─────────────────────────────────
        Container(
          color: const Color(0xFF1E1E1E),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              const Icon(
                Icons.description_outlined,
                color: Color(0xFF2B579A),
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SRS_$safeName.docx',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontSize: 12.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B579A).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF2B579A).withOpacity(0.4)),
                ),
                child: Text(
                  'v$version',
                  style: const TextStyle(
                    color: Color(0xFF7AB0E8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── Gray Word desktop ─────────────────────────────────────────────
        Expanded(
          child: Container(
            color: const Color(0xFF525659),
            child: InteractiveViewer(
                      transformationController: _transformController,
                      // do not allow panning outside the page
                      boundaryMargin: EdgeInsets.zero,
                      minScale: _fitScale,
                      maxScale: 3.0,
                      constrained: false,
                      panAxis: PanAxis.free,
                      onInteractionEnd: (details) {
                        // Ensure the final scale is not smaller than the computed _fitScale
                        // (which fits the page to one axis). If it is, snap to _fitScale
                        // and center the page in the available area.
                        // screenSize no longer needed
                        final currentScale = _transformController.value.getMaxScaleOnAxis();
                        final minAllowed = _fitScale;
                        if (currentScale < minAllowed) {
                          // Snap to minAllowed and always apply a fixed 4px margin
                          final newScale = minAllowed;
                          final marginPx = 4.0;
                          final offsetX = marginPx / newScale;
                          final offsetY = marginPx / newScale;
                          final matrix = Matrix4.identity()
                            ..translate(offsetX, offsetY)
                            ..scale(newScale, newScale, 1);
                          _transformController.value = matrix;
                        }
                      },
                      child: SizedBox(
                    width: 794.0,
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        _buildDocumentPage(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
          ),
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
          'Vista Previa',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                _AppBarBtn(
                  label: 'PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  color: _pink,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('La descarga de PDF estará disponible pronto'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
_generatingWord
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : _AppBarBtn(
                        label: 'Word',
                        icon: Icons.description_outlined,
                        color: const Color(0xFF2B579A),
                        onTap: () async {
                          if (responseData == null) return;
                          setState(() => _generatingWord = true);
                          final error = await SrsWordService.generateAndOpen(
                            responseData!,
                          );
                          if (!mounted) return;
                          setState(() => _generatingWord = false);
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error)),
                            );
                          }
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _pink))
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
                        loadPreview();
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
          : _buildWordViewer(),
    );
  }
}

class _AppBarBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AppBarBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
