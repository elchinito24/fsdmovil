import 'package:flutter/material.dart';
import 'dart:math';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/services/srs_pdf_service.dart';
import 'package:fsdmovil/services/srs_word_service.dart';

// ── Brand / UI tokens ────────────────────────────────────────────────────────
const _primary = Color(0xFFE8365D);
const _darkBg = Color(0xFF0F1017);
const _bgSecondary = Color(0xFF13151F);
const _border = Color(0xFF1F2130);
const _textPrimary = Color(0xFFFFFFFF);
const _textSecondary = Color(0xFFB0B8C8);

// ── Document (always light, simulates printed page) ───────────────────────────
const _docBg = Color(0xFFFFFFFF);
const _docText = Color(0xFF1A202C);
const _docTextLight = Color(0xFF334155);
const _docTextMuted = Color(0xFF475569);
const _docTextGray = Color(0xFF64748B);
const _docTextSub = Color(0xFF94A3B8);
const _docBorder = Color(0xFFE2E8F0);
const _docTableHeader = Color(0xFFF8FAFC);
const _wordBlue = Color(0xFF2B579A);


class PreviewScreen extends StatefulWidget {
  final int projectId;
  const PreviewScreen({super.key, required this.projectId});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool loading = true;
  bool _generatingWord = false;
  bool _generatingPdf  = false;
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

  Widget _secHeading(String n, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (n.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(n,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _docTextGray,
                          letterSpacing: 0.8,
                        )),
                  ),
                Text(title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _docText,
                      letterSpacing: -0.1,
                    )),
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 2, color: _docText),
          ],
        ),
      );

  Widget _subHeading(String n, String title, {bool first = false}) => Padding(
        padding: EdgeInsets.only(top: first ? 0 : 22, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (n.isNotEmpty)
              SizedBox(
                width: 36,
                child: Text(n,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _docTextSub,
                    )),
              ),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _docTextLight,
                  )),
            ),
          ],
        ),
      );

  Widget _docP(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, height: 1.75, color: _docTextLight)),
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
                          radius: 3, backgroundColor: _docTextGray),
                    ),
                    Expanded(
                      child: Text(safeText(item),
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.75,
                              color: _docTextLight)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _docDefinitionsList(List items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final data = Map<String, dynamic>.from(item);
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 13, height: 1.75, color: _docTextLight),
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
            color: const Color(0xFFFAFBFC),
            border: Border.all(color: _docBorder),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(safeText(data['name'], fallback: 'Usuario'),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _docText)),
              if (safeText(data['description'], fallback: '').isNotEmpty)
                _docFieldRow('Descripción', safeText(data['description'])),
              if (safeText(data['characteristics'], fallback: '').isNotEmpty)
                _docFieldRow(
                    'Características', safeText(data['characteristics'])),
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
                fontSize: 12, height: 1.55, color: _docTextMuted),
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

  // ─── Requirements / data tables ──────────────────────────────────────────

  Color _priorityColor(String p) {
    switch (p.trim().toLowerCase()) {
      case 'high':
      case 'alta':
        return const Color(0xFFDC2626);
      case 'medium':
      case 'media':
        return const Color(0xFFB45309);
      case 'low':
      case 'baja':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _priorityBg(String p) {
    switch (p.trim().toLowerCase()) {
      case 'high':
      case 'alta':
        return const Color(0xFFFEE2E2);
      case 'medium':
      case 'media':
        return const Color(0xFFFEF9C3);
      case 'low':
      case 'baja':
        return const Color(0xFFDCFCE7);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  String _priorityLabel(String p) {
    switch (p.trim().toLowerCase()) {
      case 'high':
        return 'ALTA';
      case 'medium':
        return 'MEDIA';
      case 'low':
        return 'BAJA';
      default:
        return p.toUpperCase();
    }
  }

  String _categoryLabel(String c) {
    const labels = {
      'performance': 'Rendimiento',
      'security': 'Seguridad',
      'usability': 'Usabilidad',
      'reliability': 'Confiabilidad',
      'scalability': 'Escalabilidad',
      'other': 'Otro',
    };
    return labels[c.trim().toLowerCase()] ?? c;
  }

  Widget _reqHeaderCell(String text, {int flex = 1}) => Expanded(
        flex: flex,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          color: _docTableHeader,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _docTextGray,
              letterSpacing: 1.0,
            ),
          ),
        ),
      );

  Widget _reqDataCell(String text, {int flex = 1}) => Expanded(
        flex: flex,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 11, height: 1.5, color: _docTextLight),
          ),
        ),
      );

  Widget _reqBoldCell(String text, {int flex = 1}) => Expanded(
        flex: flex,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 11,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: _docText),
          ),
        ),
      );

  Widget _reqIdCell(String text) => Expanded(
        flex: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: _docTextMuted,
              ),
            ),
          ),
        ),
      );

  Widget _vDiv() => Container(width: 0.6, color: _docBorder);

  Widget _docFunctionalReqTable(List items) {
    if (items.isEmpty) {
      return _docP('Sin requisitos funcionales registrados');
    }
    return Container(
      decoration:
          BoxDecoration(border: Border.all(color: _docBorder, width: 0.8)),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(children: [
              _reqHeaderCell('ID', flex: 2),
              _vDiv(),
              _reqHeaderCell('TÍTULO', flex: 4),
              _vDiv(),
              _reqHeaderCell('PRIORIDAD', flex: 3),
              _vDiv(),
              _reqHeaderCell('DESCRIPCIÓN', flex: 6),
            ]),
          ),
          ...items.asMap().entries.map((e) {
            final idx = e.key;
            final item = Map<String, dynamic>.from(e.value);
            final priority =
                (item['priority'] ?? '').toString().trim();
            final pc = _priorityColor(priority);
            return Container(
              decoration: BoxDecoration(
                color: idx.isEven ? Colors.white : const Color(0xFFF8FAFF),
                border: const Border(
                    top: BorderSide(color: _docBorder, width: 0.6)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _reqIdCell(safeText(item['id'], fallback: '-')),
                    _vDiv(),
                    _reqBoldCell(
                        safeText(item['title'], fallback: ''),
                        flex: 4),
                    _vDiv(),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 7),
                        child: priority.isEmpty
                            ? const SizedBox()
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _priorityBg(priority),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _priorityLabel(priority),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: pc,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    _vDiv(),
                    _reqDataCell(
                        safeText(item['description'], fallback: ''),
                        flex: 6),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _docNonFunctionalReqTable(List items) {
    if (items.isEmpty) {
      return _docP('Sin requisitos no funcionales registrados');
    }
    return Container(
      decoration:
          BoxDecoration(border: Border.all(color: _docBorder, width: 0.8)),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(children: [
              _reqHeaderCell('ID', flex: 2),
              _vDiv(),
              _reqHeaderCell('TÍTULO', flex: 4),
              _vDiv(),
              _reqHeaderCell('CATEGORÍA', flex: 3),
              _vDiv(),
              _reqHeaderCell('DESCRIPCIÓN', flex: 6),
            ]),
          ),
          ...items.asMap().entries.map((e) {
            final idx = e.key;
            final item = Map<String, dynamic>.from(e.value);
            return Container(
              decoration: BoxDecoration(
                color: idx.isEven ? Colors.white : const Color(0xFFF8FAFF),
                border: const Border(
                    top: BorderSide(color: _docBorder, width: 0.6)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _reqIdCell(safeText(item['id'], fallback: '-')),
                    _vDiv(),
                    _reqBoldCell(
                        safeText(item['title'], fallback: ''),
                        flex: 4),
                    _vDiv(),
                    _reqDataCell(
                        _categoryLabel(safeText(item['category'], fallback: '')),
                        flex: 3),
                    _vDiv(),
                    _reqDataCell(
                        safeText(item['description'], fallback: ''),
                        flex: 6),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _docMembersTable(List items) {
    if (items.isEmpty) return _docP('Sin miembros registrados');
    return Container(
      decoration:
          BoxDecoration(border: Border.all(color: _docBorder, width: 0.8)),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(children: [
              _reqHeaderCell('NOMBRE', flex: 3),
              _vDiv(),
              _reqHeaderCell('ROL', flex: 2),
              _vDiv(),
              _reqHeaderCell('EMAIL', flex: 3),
            ]),
          ),
          ...items.asMap().entries.map((e) {
            final idx = e.key;
            final item = Map<String, dynamic>.from(e.value);
            return Container(
              decoration: BoxDecoration(
                color:
                    idx.isEven ? Colors.white : const Color(0xFFF8FAFC),
                border: const Border(
                    top: BorderSide(color: _docBorder, width: 0.6)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _reqBoldCell(
                        safeText(item['name'], fallback: ''),
                        flex: 3),
                    _vDiv(),
                    _reqDataCell(
                        safeText(item['role'], fallback: ''),
                        flex: 2),
                    _vDiv(),
                    _reqDataCell(
                        safeText(item['email'], fallback: ''),
                        flex: 3),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _docRevisionTable(List items) {
    if (items.isEmpty) return _docP('Sin historial de revisiones');
    return Container(
      decoration:
          BoxDecoration(border: Border.all(color: _docBorder, width: 0.8)),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(children: [
              _reqHeaderCell('VERSIÓN', flex: 2),
              _vDiv(),
              _reqHeaderCell('FECHA', flex: 2),
              _vDiv(),
              _reqHeaderCell('DESCRIPCIÓN', flex: 5),
              _vDiv(),
              _reqHeaderCell('AUTOR', flex: 3),
            ]),
          ),
          ...items.asMap().entries.map((e) {
            final idx = e.key;
            final item = Map<String, dynamic>.from(e.value);
            return Container(
              decoration: BoxDecoration(
                color:
                    idx.isEven ? Colors.white : const Color(0xFFF8FAFF),
                border: const Border(
                    top: BorderSide(color: _docBorder, width: 0.6)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _reqDataCell(
                        safeText(item['version'], fallback: ''),
                        flex: 2),
                    _vDiv(),
                    _reqDataCell(
                        safeText(item['date'], fallback: ''),
                        flex: 2),
                    _vDiv(),
                    _reqDataCell(
                        safeText(item['description'], fallback: ''),
                        flex: 5),
                    _vDiv(),
                    _reqDataCell(
                        safeText(item['author'], fallback: ''),
                        flex: 3),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Approval table ────────────────────────────────────────────────────────

  Widget _docApprovalTable(List items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration:
          BoxDecoration(border: Border.all(color: _docBorder, width: 0.8)),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(children: [
              _reqHeaderCell('ROL', flex: 3),
              _vDiv(),
              _reqHeaderCell('NOMBRE', flex: 3),
              _vDiv(),
              _reqHeaderCell('FECHA', flex: 2),
              _vDiv(),
              _reqHeaderCell('FIRMA', flex: 3),
            ]),
          ),
          ...items.asMap().entries.map((e) {
            final idx = e.key;
            final item = Map<String, dynamic>.from(e.value);
            return Container(
              decoration: BoxDecoration(
                color: idx.isEven ? Colors.white : const Color(0xFFF8FAFC),
                border: const Border(
                    top: BorderSide(color: _docBorder, width: 0.6)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _reqDataCell(
                        safeText(item['role'], fallback: ''), flex: 3),
                    _vDiv(),
                    _reqBoldCell(
                        safeText(item['name'], fallback: ''), flex: 3),
                    _vDiv(),
                    _reqDataCell(
                        safeText(item['date'], fallback: ''), flex: 2),
                    _vDiv(),
                    _reqDataCell(
                        safeText(item['signature'], fallback: ''),
                        flex: 3),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Document pages
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildDocumentPage() {
    final srs = Map<String, dynamic>.from(responseData?['srs_data'] ?? {});
    final metadata = Map<String, dynamic>.from(srs['metadata'] ?? {});
    final introduction =
        Map<String, dynamic>.from(srs['introduction'] ?? {});
    final overallDescription =
        Map<String, dynamic>.from(srs['overallDescription'] ?? {});
    final requirements =
        Map<String, dynamic>.from(srs['requirements'] ?? {});
    final externalInterfaces =
        Map<String, dynamic>.from(srs['externalInterfaces'] ?? {});
    final appendices = List.from(srs['appendices'] ?? []);
    final teamMembers = List.from(srs['teamMembers'] ?? []);
    final revisionHistory = List.from(srs['revisionHistory'] ?? []);
    final approvalHistory = List.from(srs['approvalHistory'] ?? []);

    final projectName =
        safeText(metadata['projectName'], fallback: 'Nombre del Proyecto');
    final version = safeText(responseData?['version'], fallback: '1.0');
    final date = safeText(metadata['createdAt'], fallback: '');
    final owner = safeText(metadata['owner'], fallback: '');
    final organization = safeText(metadata['organization'], fallback: '');
    final projectCode = safeText(metadata['projectCode'], fallback: '');
    final status = (metadata['status'] ?? '').toString().trim();
    final functionalReqs = List.from(requirements['functional'] ?? []);
    final nonFunctionalReqs =
        List.from(requirements['nonFunctional'] ?? []);
    final defs = List.from(introduction['definitions'] ?? []);
    final refs = List.from(introduction['references'] ?? []);
    final overview = (introduction['overview'] ?? '').toString().trim();
    final userClasses = List.from(overallDescription['userClasses'] ?? []);

    const statusLabels = {
      'draft': 'Borrador',
      'in_review': 'En Revisión',
      'approved': 'Aprobado',
      'archived': 'Archivado',
    };
    final statusDisplay = statusLabels[status] ?? status;

    Widget pageCard(List<Widget> children, {bool cover = false}) =>
        Container(
          width: 794,
          height: 1123,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: _docBg,
            borderRadius: const BorderRadius.all(Radius.circular(2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: cover
              ? const EdgeInsets.symmetric(horizontal: 56, vertical: 60)
              : const EdgeInsets.fromLTRB(48, 40, 48, 36),
          child: Column(
            crossAxisAlignment: cover
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: children,
          ),
        );

    Widget metaRow(String key, String value) {
      if (value.isEmpty || value == 'Sin informacion') {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 160,
              child: Text(key,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: _docTextSub,
                  )),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _docText,
                  )),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── Cover ────────────────────────────────────────────────────────
        pageCard([
          const Text('DOCUMENTO TÉCNICO',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
                color: _docTextSub,
              )),
          const SizedBox(height: 28),
          Text(projectName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: _docText,
                height: 1.15,
                letterSpacing: -0.5,
              )),
          const SizedBox(height: 12),
          const Text('Especificación de Requisitos de Software',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _docTextSub,
                fontStyle: FontStyle.italic,
              )),
          const SizedBox(height: 44),
          Center(
            child: Container(
                width: 64, height: 2, color: const Color(0xFFCBD5E0)),
          ),
          const SizedBox(height: 40),
          metaRow('CÓDIGO DEL PROYECTO', projectCode),
          metaRow('VERSIÓN', version),
          metaRow('FECHA', date),
          if (statusDisplay.isNotEmpty) metaRow('ESTADO', statusDisplay),
          metaRow('PROPIETARIO', owner),
          metaRow('ORGANIZACIÓN', organization),
          if (teamMembers.isNotEmpty) ...[  
            const SizedBox(height: 32),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('MIEMBROS DEL EQUIPO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: _docTextSub,
                    )),
              ),
            ),
            _docMembersTable(teamMembers),
          ],
        ], cover: true),

        const SizedBox(height: 24),

        // ── Historial ─────────────────────────────────────────────────────
        if (revisionHistory.isNotEmpty || approvalHistory.isNotEmpty) ...[  
          pageCard([
            _secHeading('', 'Historial de Revisiones y Aprobaciones'),
            if (revisionHistory.isNotEmpty) ...[  
              _subHeading('', 'Historial de Revisiones', first: true),
              _docRevisionTable(revisionHistory),
            ],
            if (approvalHistory.isNotEmpty) ...[  
              _subHeading('', 'Historial de Aprobaciones'),
              _docApprovalTable(approvalHistory),
            ],
          ]),
          const SizedBox(height: 24),
        ],

        // ── 1. Introducción ───────────────────────────────────────────────
        pageCard([
          _secHeading('1', 'Introducción'),
          _subHeading('1.1', 'Propósito', first: true),
          _docP(safeText(introduction['purpose'])),
          _subHeading('1.2', 'Alcance'),
          _docP(safeText(introduction['scope'])),
          if (defs.isNotEmpty) ...[  
            _subHeading('1.3', 'Definiciones, Acrónimos y Abreviaturas'),
            _docDefinitionsList(defs),
          ],
          if (refs.isNotEmpty) ...[  
            _subHeading('1.4', 'Referencias'),
            _docBulletList(refs, emptyText: 'Sin referencias registradas'),
          ],
          if (overview.isNotEmpty) ...[  
            _subHeading('1.5', 'Visión General'),
            _docP(overview),
          ],
        ]),
        const SizedBox(height: 24),

        // ── 2. Descripción General ────────────────────────────────────────
        pageCard([
          _secHeading('2', 'Descripción General'),
          _subHeading('2.1', 'Perspectiva del Producto', first: true),
          _docP(safeText(overallDescription['productPerspective'])),
          _subHeading('2.2', 'Funciones del Producto'),
          _docP(safeText(overallDescription['productFunctions'])),
          if (userClasses.isNotEmpty) ...[  
            _subHeading('2.3', 'Clases de Usuario'),
            _docUserClasses(userClasses),
          ],
          _subHeading('2.4', 'Entorno Operativo'),
          _docP(safeText(overallDescription['operatingEnvironment'])),
          _subHeading('2.5', 'Restricciones de Diseño e Implementación'),
          _docP(safeText(overallDescription['constraints'])),
          _subHeading('2.6', 'Suposiciones y Dependencias'),
          _docP(safeText(overallDescription['assumptions'])),
        ]),
        const SizedBox(height: 24),

        // ── 3. Requisitos Específicos ─────────────────────────────────────
        pageCard([
          _secHeading('3', 'Requisitos Específicos'),
          _subHeading('3.1', 'Requisitos Funcionales', first: true),
          _docFunctionalReqTable(functionalReqs),
          _subHeading('3.2', 'Requisitos No Funcionales'),
          _docNonFunctionalReqTable(nonFunctionalReqs),
        ]),
        const SizedBox(height: 24),

        // ── 4. Interfaces Externas ────────────────────────────────────────
        pageCard([
          _secHeading('4', 'Interfaces Externas'),
          _subHeading('4.1', 'Interfaces de Usuario', first: true),
          _docP(safeText(externalInterfaces['user'])),
          _subHeading('4.2', 'Interfaces de Hardware'),
          _docP(safeText(externalInterfaces['hardware'])),
          _subHeading('4.3', 'Interfaces de Software'),
          _docP(safeText(externalInterfaces['software'])),
          _subHeading('4.4', 'Interfaces de Comunicaciones'),
          _docP(safeText(externalInterfaces['communications'])),
        ]),

        // ── 5. Apéndices ──────────────────────────────────────────────────
        if (appendices.isNotEmpty) ...[  
          const SizedBox(height: 24),
          pageCard([
            _secHeading('5', 'Apéndices'),
            ...appendices.asMap().entries.map((e) {
              final i = e.key;
              final a = Map<String, dynamic>.from(e.value);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _subHeading(
                    '${String.fromCharCode(65 + i)}.',
                    safeText(a['title'], fallback: 'Apéndice ${i + 1}'),
                    first: i == 0,
                  ),
                  _docP(safeText(a['content'])),
                ],
              );
            }).toList(),
          ]),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Viewer
  // ───────────────────────────────────────────────────────────────────────

  Widget _buildWordViewer() {
    final srs = Map<String, dynamic>.from(responseData?['srs_data'] ?? {});
    final metadata = Map<String, dynamic>.from(srs['metadata'] ?? {});
    final projectName = safeText(metadata['projectName'], fallback: 'Documento');
    final version = safeText(responseData?['version'], fallback: '1.0');
    final safeName = projectName.replaceAll(' ', '_');

    return Column(
      children: [
        // ── Word-style title bar ──────────────────────────────────────────
        Container(
          color: const Color(0xFF1A1C27),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              const Icon(Icons.description_outlined, color: _wordBlue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SRS_$safeName.docx',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _wordBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _wordBlue.withOpacity(0.35)),
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

        // ── Document desktop ──────────────────────────────────────────────
        Expanded(
          child: Container(
            key: _viewerKey,
            color: const Color(0xFF525659),
            child: Listener(
              onPointerDown: (_) {
                final snap = _transformController.value.clone();
                _transformController.value = snap;
              },
              child: InteractiveViewer(
                transformationController: _transformController,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                minScale: _fitScale,
                maxScale: 3.0,
                constrained: false,
                panAxis: PanAxis.free,
                interactionEndFrictionCoefficient: 0.01,
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
        backgroundColor: _bgSecondary,
        foregroundColor: _textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
        title: const Text(
          'Vista Previa',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: _textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                // PDF
                _generatingPdf
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primary,
                            ),
                          ),
                        ),
                      )
                    : _ToolbarBtn(
                        label: 'PDF',
                        icon: Icons.picture_as_pdf_outlined,
                        color: _primary,
                        onTap: () async {
                          if (responseData == null) return;
                          setState(() => _generatingPdf = true);
                          final error = await SrsPdfService.generateAndOpen(
                              responseData!);
                          if (!mounted) return;
                          setState(() => _generatingPdf = false);
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(error),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: _primary,
                              ),
                            );
                          }
                        },
                      ),
                const SizedBox(width: 8),
                // Word download
                _generatingWord
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                      )
                    : _ToolbarBtn(
                        label: 'Word',
                        icon: Icons.description_outlined,
                        color: _wordBlue,
                        onTap: () async {
                          if (responseData == null) return;
                          setState(() => _generatingWord = true);
                          final error = await SrsWordService.generateAndOpen(
                              responseData!);
                          if (!mounted) return;
                          setState(() => _generatingWord = false);
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(error),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: _primary,
                              ),
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
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : errorMessage != null
              ? _buildError()
              : _buildWordViewer(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: _primary.withOpacity(0.3)),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: _primary, size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'Error al cargar',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    loading = true;
                    errorMessage = null;
                  });
                  loadPreview();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar action button
// ─────────────────────────────────────────────────────────────────────────────

class _ToolbarBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ToolbarBtn({
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
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.28),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}