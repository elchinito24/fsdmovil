import 'package:flutter/material.dart';
import 'dart:math';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/services/srs_word_service.dart';

const _pink = Color(0xFFE8365D);
const _darkBg = Color(0xFF0F1017);
const _textGrey = Color(0xFF8E8E93);

const _docBg = Color(0xFFFFFFFF);
const _docText = Color(0xFF1A1A1A);
const _docTextLight = Color(0xFF444444);
const _docHeading1 = Color(0xFF1F3864);
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

  final TransformationController _transformController = TransformationController();
  bool _transformApplied = false;
  double _fitScale = 0.01;

  final GlobalKey _viewerKey = GlobalKey();
  final GlobalKey _childKey = GlobalKey();

  // Margen visible alrededor de la hoja en pixeles de pantalla
  static const double _kMargin = 4.0;

  // ───────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ───────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Clampear en CADA cambio de la matriz, incluyendo los frames
    // de la animacion interna de inercia despues de soltar el dedo.
    _transformController.addListener(_clampTransform);
    loadPreview();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _recalcFitScale();
  }

  void _recalcFitScale() {
    const docWidth = 794.0;
    const docHeight = 1123.0;
    final screen = MediaQuery.of(context).size;
    final newScale = min(
      (screen.width - _kMargin * 2) / docWidth,
      (screen.height - _kMargin * 2) / docHeight,
    );
    if ((newScale - _fitScale).abs() > 0.001) {
      _fitScale = newScale;
      if (!_transformApplied) {
        _transformApplied = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applyInitialTransform();
        });
      }
    }
  }

  @override
  void dispose() {
    _transformController.removeListener(_clampTransform);
    _transformController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Transform helpers
  // ───────────────────────────────────────────────────────────────────────

  // Centra la hoja al fit-scale inicial.
  void _applyInitialTransform([int attempt = 0]) {
    if (!mounted) return;
    try {
      final vCtx = _viewerKey.currentContext;
      final cCtx = _childKey.currentContext;
      if (vCtx != null && cCtx != null) {
        final vSize = (vCtx.findRenderObject() as RenderBox).size;
        final cSize = (cCtx.findRenderObject() as RenderBox).size;
        final s = 1.0; // Sin zoom, escala real
        // Centrar horizontalmente, pegar arriba
        final tx = (vSize.width - cSize.width * s) / 2.0;
        final ty = _kMargin;
        _transformController.value = Matrix4.identity()
          ..translate(tx, ty)
          ..scale(s, s, 1.0);
        return;
      }
    } catch (_) {}

    if (attempt < 5) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyInitialTransform(attempt + 1);
      });
    }
  }

  // Limita el pan en tiempo real.
  //
  // La matriz de InteractiveViewer (constrained:false, sin rotacion) tiene
  // la forma column-major:
  //
  //   col0  col1  col2  col3
  //   [ s    0     0    tx  ]  row0
  //   [ 0    s     0    ty  ]  row1
  //   [ 0    0     1    0   ]  row2
  //   [ 0    0     0    1   ]  row3
  //
  // En storage (column-major):
  //   index = col*4 + row
  //   storage[0]  = s   (col0,row0)
  //   storage[5]  = s   (col1,row1)
  //   storage[12] = tx  (col3,row0)  <- px de PANTALLA
  //   storage[13] = ty  (col3,row1)  <- px de PANTALLA
  //
  // Esto es cierto cuando la matriz se construye como:
  //   Matrix4.identity()..translate(tx,ty)..scale(s,s,1)
  // que es exactamente lo que hace InteractiveViewer internamente.
  void _clampTransform() {
    try {
      final vCtx = _viewerKey.currentContext;
      final cCtx = _childKey.currentContext;
      if (vCtx == null || cCtx == null) return;

      final vSize = (vCtx.findRenderObject() as RenderBox).size;
      final cSize = (cCtx.findRenderObject() as RenderBox).size;

      final m     = _transformController.value;
      final scale = m.getMaxScaleOnAxis();

      // Posicion actual de la esquina (0,0) del hijo en pantalla
      double sx = m.storage[12]; // borde izquierdo de la hoja en px pantalla
      double sy = m.storage[13]; // borde superior  de la hoja en px pantalla

      final scaledW = cSize.width  * scale;
      final scaledH = cSize.height * scale;

      // ── Horizontal ────────────────────────────────────────────────────
      if (scaledW <= vSize.width) {
        // La hoja es mas angosta que la pantalla: centrar siempre
        sx = (vSize.width - scaledW) / 2.0;
      } else {
        // La hoja es mas ancha:
        //   borde izq (sx) no puede ser mayor que _kMargin
        //     → si sx > _kMargin hay espacio vacio a la izquierda → mover izq
        //   borde der (sx + scaledW) no puede ser menor que vSize.width - _kMargin
        //     → si sx < vSize.width - scaledW - _kMargin hay espacio vacio a la derecha
        //
        //   minSx = vSize.width - scaledW - _kMargin  (negativo normalmente)
        //   maxSx = _kMargin
        sx = sx.clamp(vSize.width - scaledW - _kMargin, _kMargin);
      }

      // ── Vertical ──────────────────────────────────────────────────────
      if (scaledH <= vSize.height) {
        sy = (vSize.height - scaledH) / 2.0;
      } else {
        sy = sy.clamp(vSize.height - scaledH - _kMargin, _kMargin);
      }

      // Solo actualizar si cambio algo (evitar rebuilds innecesarios)
      if ((sx - m.storage[12]).abs() > 0.1 ||
          (sy - m.storage[13]).abs() > 0.1) {
        final fixed = m.clone();
        fixed.storage[12] = sx;
        fixed.storage[13] = sy;
        _transformController.value = fixed;
      }
    } catch (_) {}
  }

  // ───────────────────────────────────────────────────────────────────────
  // Data
  // ───────────────────────────────────────────────────────────────────────

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

  String safeText(dynamic value, {String fallback = 'Sin informacion'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Document widgets
  // ───────────────────────────────────────────────────────────────────────

  Widget _docH1(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _docHeading1,
                letterSpacing: 0.2)),
      );

  Widget _docH2(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _docHeading2)),
      );

  Widget _docP(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, height: 1.7, color: _docTextLight)),
      );

  Widget _docBulletList(List items, {String emptyText = 'Sin informacion'}) {
    if (items.isEmpty) return _docP(emptyText);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 8),
                      child: CircleAvatar(
                          radius: 3, backgroundColor: _docAccent),
                    ),
                    Expanded(
                      child: Text(safeText(item),
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.7,
                              color: _docTextLight)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _docDefinitionsList(List items) {
    if (items.isEmpty) return _docP('Sin informacion');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final data = Map<String, dynamic>.from(item);
        return Padding(
          padding: const EdgeInsets.only(top: 6, left: 8),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 13, height: 1.7, color: _docTextLight),
              children: [
                TextSpan(
                    text: '${safeText(data['term'], fallback: '')}: ',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: _docText)),
                TextSpan(
                    text: safeText(data['definition'], fallback: '')),
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
              Text(safeText(data['name'], fallback: 'Usuario'),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _docText)),
              if (safeText(data['id'], fallback: '').isNotEmpty)
                _docFieldRow('ID', safeText(data['id'])),
              _docFieldRow('Descripcion', safeText(data['description'])),
              _docFieldRow(
                  'Caracteristicas', safeText(data['characteristics'])),
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
            style: const TextStyle(
                fontSize: 12, height: 1.5, color: _docTextLight),
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: _docText)),
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
      ['Version', version],
      ['Fecha', date],
      ['Autor(es)', author],
      ['Organizacion', organization],
    ];
    return Table(
      border: TableBorder.all(color: _docBorder, width: 0.8),
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth()
      },
      children: rows.map((row) {
        return TableRow(
          decoration: BoxDecoration(
            color: row == rows.first
                ? _docTableHeader
                : const Color(0xFFFFFFFF),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
              child: Text(row[0],
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _docText)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
              child: Text(row[1],
                  style: const TextStyle(
                      fontSize: 12, color: _docTextLight)),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Document pages
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildDocumentPage() {
    final srs =
        Map<String, dynamic>.from(responseData?['srs_data'] ?? {});
    final metadata = Map<String, dynamic>.from(srs['metadata'] ?? {});
    final introduction =
        Map<String, dynamic>.from(srs['introduction'] ?? {});
    final overallDescription =
        Map<String, dynamic>.from(srs['overallDescription'] ?? {});
    final specificRequirements =
        Map<String, dynamic>.from(srs['specificRequirements'] ?? {});

    final projectName = safeText(metadata['projectName']);
    final version =
        safeText(responseData?['version'], fallback: '1.0');
    final date = safeText(metadata['createdAt']);
    final author = safeText(metadata['owner']);
    final organization = safeText(metadata['organization']);

    final pages = <(String, List<Widget>)>[
      // Portada
      (
        '1',
        [
          Center(
            child: Column(children: [
              Container(width: 56, height: 6, color: _docHeading1),
              const SizedBox(height: 20),
              const Text(
                'ESPECIFICACION DE\nREQUISITOS DE SOFTWARE',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _docHeading1,
                    letterSpacing: 1,
                    height: 1.4),
              ),
              const SizedBox(height: 4),
              const Text('IEEE Std 830',
                  style: TextStyle(
                      fontSize: 12,
                      color: _docAccent,
                      letterSpacing: 2)),
              const SizedBox(height: 28),
            ]),
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
      // Introduccion
      (
        '2',
        [
          _docH1('1. Introduccion'),
          _docH2('1.1 Proposito'),
          _docP(safeText(introduction['purpose'])),
          _docH2('1.2 Alcance'),
          _docP(safeText(introduction['scope'])),
          _docH2('1.3 Definiciones, Acronimos y Abreviaturas'),
          _docDefinitionsList(
              List.from(introduction['definitions'] ?? [])),
          _docH2('1.4 Referencias'),
          _docBulletList(
              List.from(introduction['references'] ?? []),
              emptyText: 'Sin referencias registradas'),
          _docH2('1.5 Vision General'),
          _docP(safeText(introduction['overview'])),
        ],
      ),
      // Descripcion general
      (
        '3',
        [
          _docH1('2. Descripcion General'),
          _docH2('2.1 Perspectiva del Producto'),
          _docP(safeText(overallDescription['productPerspective'])),
          _docH2('2.2 Funciones del Producto'),
          _docP(safeText(overallDescription['productFunctions'])),
          _docH2('2.3 Clases de Usuario'),
          _docUserClasses(
              List.from(overallDescription['userClasses'] ?? [])),
          _docH2('2.4 Entorno Operativo'),
          _docP(safeText(overallDescription['operatingEnvironment'])),
          _docH2('2.5 Restricciones'),
          _docP(safeText(overallDescription['constraints'])),
          _docH2('2.6 Suposiciones y Dependencias'),
          _docP(safeText(overallDescription['assumptions'])),
        ],
      ),
      // Requisitos especificos
      (
        '4',
        [
          _docH1('3. Requisitos Especificos'),
          _docH2('3.1 Interfaces Externas'),
          _docP(safeText(specificRequirements['externalInterfaces'])),
          _docH2('3.2 Requisitos Funcionales'),
          _docBulletList(
              List.from(
                  specificRequirements['functionalRequirements'] ?? []),
              emptyText: 'Sin requisitos funcionales registrados'),
          _docH2('3.3 Requisitos No Funcionales'),
          _docBulletList(
              List.from(specificRequirements[
                      'nonFunctionalRequirements'] ??
                  []),
              emptyText: 'Sin requisitos no funcionales registrados'),
          _docH2('3.4 Reglas de Negocio'),
          _docBulletList(
              List.from(specificRequirements['businessRules'] ?? []),
              emptyText: 'Sin reglas de negocio registradas'),
          _docH2('3.5 Casos de Uso'),
          _docBulletList(
              List.from(specificRequirements['useCases'] ?? []),
              emptyText: 'Sin casos de uso registrados'),
          const SizedBox(height: 16),
          _docDivider(),
          Center(
            child: Text(
                'Documento generado por FSD  •  v$version',
                style:
                    const TextStyle(fontSize: 11, color: _textGrey)),
          ),
        ],
      ),
    ];

    return Column(
      children: pages.map((entry) {
        final pageNum = entry.$1;
        final content = entry.$2;
        final isLast = pageNum == '4';
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('Pagina $pageNum',
                  style: TextStyle(
                      color:
                          const Color(0xFFFFFFFF).withOpacity(0.40),
                      fontSize: 11)),
            ),
            SizedBox(
              width: 794,
              height: 1123,
              child: Container(
                decoration: BoxDecoration(
                  color: _docBg,
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFF000000).withOpacity(0.40),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                        height: 5,
                        color: const Color(0xFF2B579A)),
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(96, 48, 96, 0),
                        child: ClipRect(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: content,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 32,
                      decoration: const BoxDecoration(
                        border: Border(
                            top: BorderSide(
                                color: _docBorder, width: 0.8)),
                      ),
                      alignment: Alignment.center,
                      child: Text(pageNum,
                          style: const TextStyle(
                              fontSize: 11, color: _docTextLight)),
                    ),
                  ],
                ),
              ),
            ),
            if (!isLast) const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Word viewer
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildWordViewer() {
    final srs =
        Map<String, dynamic>.from(responseData?['srs_data'] ?? {});
    final metadata =
        Map<String, dynamic>.from(srs['metadata'] ?? {});
    final projectName =
        safeText(metadata['projectName'], fallback: 'Documento');
    final version =
        safeText(responseData?['version'], fallback: '1.0');
    final safeName = projectName.replaceAll(' ', '_');

    return Column(
      children: [
        // Barra de titulo estilo Word
        Container(
          color: const Color(0xFF1E1E1E),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              const Icon(Icons.description_outlined,
                  color: Color(0xFF2B579A), size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text('SRS_$safeName.docx',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFFCCCCCC), fontSize: 12.5)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF2B579A).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: const Color(0xFF2B579A)
                          .withOpacity(0.4)),
                ),
                child: Text('v$version',
                    style: const TextStyle(
                        color: Color(0xFF7AB0E8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),

        // Escritorio gris estilo Word
        Expanded(
          child: Container(
            key: _viewerKey,
            color: const Color(0xFF525659),
            child: Listener(
              // Interrumpir inercia al tocar la pantalla
              onPointerDown: (_) {
                final snap = _transformController.value.clone();
                _transformController.value = snap;
              },
              child: InteractiveViewer(
                transformationController: _transformController,
                // Sin limite automatico de Flutter: lo manejamos nosotros
                boundaryMargin: const EdgeInsets.all(double.infinity),
                // No puede hacer zoom-out mas pequeno que el fit
                minScale: _fitScale,
                maxScale: 3.0,
                constrained: false,
                panAxis: PanAxis.free,
                // Friction muy alto = fling casi nulo al soltar el dedo
                interactionEndFrictionCoefficient: 0.01,
                // El clamp se aplica via _transformController.addListener
                // en cada frame, incluyendo la animacion de inercia post-fling.
                child: SizedBox(
                  key: _childKey,
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
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Build
  // ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Vista Previa',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                _AppBarBtn(
                  label: 'PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  color: _pink,
                  onTap: () =>
                      ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'La descarga de PDF estara disponible pronto'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _generatingWord
                    ? const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFFFFFF)),
                        ),
                      )
                    : _AppBarBtn(
                        label: 'Word',
                        icon: Icons.description_outlined,
                        color: const Color(0xFF2B579A),
                        onTap: () async {
                          if (responseData == null) return;
                          setState(() => _generatingWord = true);
                          final error =
                              await SrsWordService.generateAndOpen(
                                  responseData!);
                          if (!mounted) return;
                          setState(() => _generatingWord = false);
                          if (error != null) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                                    SnackBar(content: Text(error)));
                          }
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: _pink))
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: _pink, size: 48),
                        const SizedBox(height: 16),
                        Text(errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: _textGrey)),
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
                                borderRadius:
                                    BorderRadius.circular(12)),
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

// ─────────────────────────────────────────────────────────────────────────────
// AppBar button
// ─────────────────────────────────────────────────────────────────────────────

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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: const Color(0xFFFFFFFF)),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}