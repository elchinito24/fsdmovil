import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ── Color palette matching preview_screen.dart ──────────────────────────────
const _cText      = PdfColor.fromInt(0xFF1A202C);
const _cLight     = PdfColor.fromInt(0xFF334155);
const _cMuted     = PdfColor.fromInt(0xFF475569);
const _cGray      = PdfColor.fromInt(0xFF64748B);
const _cSub       = PdfColor.fromInt(0xFF94A3B8);
const _cBorder    = PdfColor.fromInt(0xFFE2E8F0);
const _cTableHdr  = PdfColor.fromInt(0xFFF8FAFC);
const _cBg        = PdfColors.white;
const _cIdBg      = PdfColor.fromInt(0xFFF1F5F9);
const _cAltRow    = PdfColor.fromInt(0xFFF8FAFF);

// Priority colors
PdfColor _priorityBg(String p) {
  switch (p.trim().toLowerCase()) {
    case 'high':
    case 'alta':   return PdfColor.fromInt(0xFFFEE2E2);
    case 'medium':
    case 'media':  return PdfColor.fromInt(0xFFFEF9C3);
    case 'low':
    case 'baja':   return PdfColor.fromInt(0xFFDCFCE7);
    default:       return PdfColor.fromInt(0xFFF3F4F6);
  }
}

PdfColor _priorityFg(String p) {
  switch (p.trim().toLowerCase()) {
    case 'high':
    case 'alta':   return PdfColor.fromInt(0xFFDC2626);
    case 'medium':
    case 'media':  return PdfColor.fromInt(0xFFB45309);
    case 'low':
    case 'baja':   return PdfColor.fromInt(0xFF16A34A);
    default:       return PdfColor.fromInt(0xFF6B7280);
  }
}

String _priorityLabel(String p) {
  switch (p.trim().toLowerCase()) {
    case 'high':   return 'ALTA';
    case 'medium': return 'MEDIA';
    case 'low':    return 'BAJA';
    default:       return p.toUpperCase();
  }
}

String _categoryLabel(String c) {
  const labels = {
    'performance': 'Rendimiento',
    'security':    'Seguridad',
    'usability':   'Usabilidad',
    'reliability': 'Confiabilidad',
    'scalability': 'Escalabilidad',
    'other':       'Otro',
  };
  return labels[c.trim().toLowerCase()] ?? c;
}

// ─────────────────────────────────────────────────────────────────────────────

class SrsPdfService {
  static String _safe(dynamic v, {String fallback = 'Sin información'}) {
    if (v == null) return fallback;
    final t = v.toString().trim();
    return t.isEmpty ? fallback : t;
  }

  // ── public entry point ────────────────────────────────────────────────────
  static Future<String?> generateAndOpen(
    Map<String, dynamic> responseData,
  ) async {
    try {
      final bytes = await _buildPdf(responseData);
      final srs   = Map<String, dynamic>.from(responseData['srs_data'] ?? {});
      final meta  = Map<String, dynamic>.from(srs['metadata'] ?? {});
      final name  = _safe(meta['projectName'])
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');

      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/SRS_$name.pdf');
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        return 'No se encontró una app para abrir .pdf: ${result.message}';
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── PDF builder ───────────────────────────────────────────────────────────
  static Future<List<int>> _buildPdf(Map<String, dynamic> responseData) async {
    final font     = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontItal = await PdfGoogleFonts.interItalic();

    final srs             = Map<String, dynamic>.from(responseData['srs_data']        ?? {});
    final meta            = Map<String, dynamic>.from(srs['metadata']                 ?? {});
    final intro           = Map<String, dynamic>.from(srs['introduction']             ?? {});
    final overall         = Map<String, dynamic>.from(srs['overallDescription']       ?? {});
    final requirements    = Map<String, dynamic>.from(srs['requirements']             ?? {});
    final extInterfaces   = Map<String, dynamic>.from(srs['externalInterfaces']       ?? {});
    final appendices      = List.from(srs['appendices']      ?? []);
    final teamMembers     = List.from(srs['teamMembers']     ?? []);
    final revisionHistory = List.from(srs['revisionHistory'] ?? []);
    final approvalHistory = List.from(srs['approvalHistory'] ?? []);
    final functionalReqs  = List.from(requirements['functional']    ?? []);
    final nonFuncReqs     = List.from(requirements['nonFunctional'] ?? []);
    final defs            = List.from(intro['definitions'] ?? []);
    final refs            = List.from(intro['references']  ?? []);
    final userClasses     = List.from(overall['userClasses'] ?? []);

    final projectName = _safe(meta['projectName']);
    final version     = _safe(responseData['version'], fallback: '1.0');
    final date        = _safe(meta['createdAt']);
    final owner       = _safe(meta['owner']);
    final org         = _safe(meta['organization']);
    final projectCode = _safe(meta['projectCode'], fallback: '');
    final statusRaw   = (meta['status'] ?? '').toString().trim();
    const statusMap   = {
      'draft':     'Borrador',
      'in_review': 'En Revisión',
      'approved':  'Aprobado',
      'archived':  'Archivado',
    };
    final statusDisplay = statusMap[statusRaw] ?? statusRaw;

    // ── text styles ─────────────────────────────────────────────────────────
    pw.TextStyle ts(double size, PdfColor color,
        {bool bold = false, bool italic = false, double height = 1.6}) =>
        pw.TextStyle(
          font: bold ? fontBold : (italic ? fontItal : font),
          fontSize: size,
          color: color,
          lineSpacing: (height - 1) * size,
        );

    // ── helpers ──────────────────────────────────────────────────────────────

    pw.Widget secHeading(String n, String title) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (n.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 10),
                    child: pw.Text(n,
                        style: ts(9, _cGray, bold: true)),
                  ),
                pw.Text(title, style: ts(16, _cText, bold: true)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 1.5, color: _cText),
            pw.SizedBox(height: 18),
          ],
        );

    pw.Widget subHeading(String n, String title, {bool first = false}) =>
        pw.Padding(
          padding: pw.EdgeInsets.only(top: first ? 0 : 16, bottom: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (n.isNotEmpty)
                pw.SizedBox(
                  width: 30,
                  child: pw.Text(n, style: ts(9, _cSub, bold: true)),
                ),
              pw.Text(title, style: ts(11, _cLight, bold: true)),
            ],
          ),
        );

    pw.Widget docP(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Text(text, style: ts(10, _cLight)),
        );

    pw.Widget metaRow(String key, String value) {
      if (value.isEmpty || value == 'Sin información') {
        return pw.SizedBox.shrink();
      }
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 140,
              child: pw.Text(key, style: ts(7.5, _cSub, bold: true)),
            ),
            pw.Expanded(
              child: pw.Text(value, style: ts(11, _cText, bold: true)),
            ),
          ],
        ),
      );
    }

    // ── req table ────────────────────────────────────────────────────────────

    pw.Widget reqTable({
      required List<String> headers,
      required List<int> flexes,
      required List<List<pw.Widget>> rows,
    }) {
      final border = pw.TableBorder.all(color: _cBorder, width: 0.6);
      final headerRow = pw.TableRow(
        decoration: const pw.BoxDecoration(color: _cTableHdr),
        children: headers.asMap().entries.map((e) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text(e.value,
                style: ts(7.5, _cGray, bold: true)),
          );
        }).toList(),
      );

      final dataRows = rows.asMap().entries.map((rowEntry) {
        final idx = rowEntry.key;
        final cells = rowEntry.value;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
              color: idx.isEven ? _cBg : _cAltRow),
          children: cells.map((cell) => pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: cell,
              )).toList(),
        );
      }).toList();

      return pw.Table(
        border: border,
        columnWidths: {
          for (int i = 0; i < flexes.length; i++)
            i: pw.FlexColumnWidth(flexes[i].toDouble()),
        },
        children: [headerRow, ...dataRows],
      );
    }

    pw.Widget priorityBadge(String p) => pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: pw.BoxDecoration(
            color: _priorityBg(p),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Text(_priorityLabel(p),
              style: ts(7.5, _priorityFg(p), bold: true)),
        );

    pw.Widget idBadge(String id) => pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: pw.BoxDecoration(
            color: _cIdBg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Text(id, style: ts(8, _cMuted)),
        );

    // ── page card ────────────────────────────────────────────────────────────
    pw.Widget pageCard(List<pw.Widget> children, {bool cover = false}) =>
        pw.Container(
          padding: cover
              ? const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 52)
              : const pw.EdgeInsets.fromLTRB(40, 36, 40, 32),
          color: _cBg,
          child: pw.Column(
            crossAxisAlignment: cover
                ? pw.CrossAxisAlignment.center
                : pw.CrossAxisAlignment.start,
            children: children,
          ),
        );

    // ── build pages ──────────────────────────────────────────────────────────
    final doc = pw.Document();

    // Helper to add a full page
    void addPage(pw.Widget content) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => content,
      ));
    }

    // ── COVER ────────────────────────────────────────────────────────────────
    final coverChildren = <pw.Widget>[
      pw.Text('DOCUMENTO TÉCNICO',
          textAlign: pw.TextAlign.center,
          style: ts(8, _cSub, bold: true)),
      pw.SizedBox(height: 22),
      pw.Text(projectName,
          textAlign: pw.TextAlign.center,
          style: ts(28, _cText, bold: true)),
      pw.SizedBox(height: 10),
      pw.Text('Especificación de Requisitos de Software',
          textAlign: pw.TextAlign.center,
          style: ts(12, _cSub, italic: true)),
      pw.SizedBox(height: 36),
      pw.Center(
          child: pw.Container(
              width: 56, height: 1.5, color: PdfColor.fromInt(0xFFCBD5E0))),
      pw.SizedBox(height: 32),
      metaRow('CÓDIGO DEL PROYECTO', projectCode),
      metaRow('VERSIÓN', version),
      metaRow('FECHA', date),
      if (statusDisplay.isNotEmpty) metaRow('ESTADO', statusDisplay),
      metaRow('PROPIETARIO', owner),
      metaRow('ORGANIZACIÓN', org),
    ];

    if (teamMembers.isNotEmpty) {
      coverChildren.addAll([
        pw.SizedBox(height: 28),
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text('MIEMBROS DEL EQUIPO',
              style: ts(7.5, _cSub, bold: true)),
        ),
        pw.SizedBox(height: 8),
        reqTable(
          headers: ['NOMBRE', 'ROL', 'EMAIL'],
          flexes: [3, 2, 3],
          rows: teamMembers.map((m) {
            final t = Map<String, dynamic>.from(m);
            return [
              pw.Text(_safe(t['name'],  fallback: ''), style: ts(9, _cText, bold: true)),
              pw.Text(_safe(t['role'],  fallback: ''), style: ts(9, _cLight)),
              pw.Text(_safe(t['email'], fallback: ''), style: ts(9, _cLight)),
            ] as List<pw.Widget>;
          }).toList(),
        ),
      ]);
    }

    addPage(pageCard(coverChildren, cover: true));

    // ── HISTORIAL ────────────────────────────────────────────────────────────
    if (revisionHistory.isNotEmpty || approvalHistory.isNotEmpty) {
      final children = <pw.Widget>[
        secHeading('', 'Historial de Revisiones y Aprobaciones'),
      ];
      if (revisionHistory.isNotEmpty) {
        children.add(subHeading('', 'Historial de Revisiones', first: true));
        children.add(reqTable(
          headers: ['VERSIÓN', 'FECHA', 'DESCRIPCIÓN', 'AUTOR'],
          flexes: [2, 2, 5, 3],
          rows: revisionHistory.map((r) {
            final t = Map<String, dynamic>.from(r);
            return [
              pw.Text(_safe(t['version'],     fallback: ''), style: ts(9, _cLight)),
              pw.Text(_safe(t['date'],        fallback: ''), style: ts(9, _cLight)),
              pw.Text(_safe(t['description'], fallback: ''), style: ts(9, _cLight)),
              pw.Text(_safe(t['author'],      fallback: ''), style: ts(9, _cLight)),
            ] as List<pw.Widget>;
          }).toList(),
        ));
      }
      if (approvalHistory.isNotEmpty) {
        children.add(subHeading('', 'Historial de Aprobaciones'));
        children.add(reqTable(
          headers: ['ROL', 'NOMBRE', 'FECHA', 'FIRMA'],
          flexes: [3, 3, 2, 3],
          rows: approvalHistory.map((a) {
            final t = Map<String, dynamic>.from(a);
            return [
              pw.Text(_safe(t['role'],      fallback: ''), style: ts(9, _cLight)),
              pw.Text(_safe(t['name'],      fallback: ''), style: ts(9, _cText, bold: true)),
              pw.Text(_safe(t['date'],      fallback: ''), style: ts(9, _cLight)),
              pw.Text(_safe(t['signature'], fallback: ''), style: ts(9, _cLight)),
            ] as List<pw.Widget>;
          }).toList(),
        ));
      }
      addPage(pageCard(children));
    }

    // ── 1. INTRODUCCIÓN ──────────────────────────────────────────────────────
    final introChildren = <pw.Widget>[
      secHeading('1', 'Introducción'),
      subHeading('1.1', 'Propósito', first: true),
      docP(_safe(intro['purpose'])),
      subHeading('1.2', 'Alcance'),
      docP(_safe(intro['scope'])),
    ];
    if (defs.isNotEmpty) {
      introChildren.add(subHeading('1.3', 'Definiciones, Acrónimos y Abreviaturas'));
      for (final d in defs) {
        final m = Map<String, dynamic>.from(d);
        introChildren.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(
                  text: '${_safe(m["term"], fallback: "")}: ',
                  style: ts(10, _cText, bold: true)),
              pw.TextSpan(
                  text: _safe(m['definition'], fallback: ''),
                  style: ts(10, _cLight)),
            ]),
          ),
        ));
      }
    }
    if (refs.isNotEmpty) {
      introChildren.add(subHeading('1.4', 'Referencias'));
      for (final r in refs) {
        introChildren.add(pw.Row(children: [
          pw.Container(
              width: 4,
              height: 4,
              margin: const pw.EdgeInsets.only(right: 6, top: 4),
              decoration: const pw.BoxDecoration(
                  color: _cGray, shape: pw.BoxShape.circle)),
          pw.Expanded(child: pw.Text(r.toString(), style: ts(10, _cLight))),
        ]));
      }
    }
    final overview = (intro['overview'] ?? '').toString().trim();
    if (overview.isNotEmpty) {
      introChildren.add(subHeading('1.5', 'Visión General'));
      introChildren.add(docP(overview));
    }
    addPage(pageCard(introChildren));

    // ── 2. DESCRIPCIÓN GENERAL ───────────────────────────────────────────────
    final descChildren = <pw.Widget>[
      secHeading('2', 'Descripción General'),
      subHeading('2.1', 'Perspectiva del Producto', first: true),
      docP(_safe(overall['productPerspective'])),
      subHeading('2.2', 'Funciones del Producto'),
      docP(_safe(overall['productFunctions'])),
    ];
    if (userClasses.isNotEmpty) {
      descChildren.add(subHeading('2.3', 'Clases de Usuario'));
      for (final u in userClasses) {
        final m = Map<String, dynamic>.from(u);
        descChildren.add(pw.Container(
          margin: const pw.EdgeInsets.only(top: 6),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFFAFBFC),
            border: pw.Border.all(color: _cBorder),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(_safe(m['name'], fallback: 'Usuario'),
                  style: ts(10, _cText, bold: true)),
              if (_safe(m['description'], fallback: '').isNotEmpty)
                pw.Text('Descripción: ${_safe(m["description"])}',
                    style: ts(9, _cMuted)),
              if (_safe(m['characteristics'], fallback: '').isNotEmpty)
                pw.Text('Características: ${_safe(m["characteristics"])}',
                    style: ts(9, _cMuted)),
            ],
          ),
        ));
      }
    }
    descChildren.addAll([
      subHeading('2.4', 'Entorno Operativo'),
      docP(_safe(overall['operatingEnvironment'])),
      subHeading('2.5', 'Restricciones de Diseño e Implementación'),
      docP(_safe(overall['constraints'])),
      subHeading('2.6', 'Suposiciones y Dependencias'),
      docP(_safe(overall['assumptions'])),
    ]);
    addPage(pageCard(descChildren));

    // ── 3. REQUISITOS ESPECÍFICOS ────────────────────────────────────────────
    final reqChildren = <pw.Widget>[
      secHeading('3', 'Requisitos Específicos'),
      subHeading('3.1', 'Requisitos Funcionales', first: true),
    ];
    if (functionalReqs.isEmpty) {
      reqChildren.add(docP('Sin requisitos funcionales registrados'));
    } else {
      reqChildren.add(reqTable(
        headers: ['ID', 'TÍTULO', 'PRIORIDAD', 'DESCRIPCIÓN'],
        flexes: [2, 4, 3, 6],
        rows: functionalReqs.map((r) {
          final t = Map<String, dynamic>.from(r);
          final p = (t['priority'] ?? '').toString();
          return [
            idBadge(_safe(t['id'], fallback: '-')),
            pw.Text(_safe(t['title'],       fallback: ''), style: ts(9, _cText, bold: true)),
            if (p.isNotEmpty) priorityBadge(p) else pw.SizedBox.shrink(),
            pw.Text(_safe(t['description'], fallback: ''), style: ts(9, _cLight)),
          ] as List<pw.Widget>;
        }).toList(),
      ));
    }
    reqChildren.add(subHeading('3.2', 'Requisitos No Funcionales'));
    if (nonFuncReqs.isEmpty) {
      reqChildren.add(docP('Sin requisitos no funcionales registrados'));
    } else {
      reqChildren.add(reqTable(
        headers: ['ID', 'TÍTULO', 'CATEGORÍA', 'DESCRIPCIÓN'],
        flexes: [2, 4, 3, 6],
        rows: nonFuncReqs.map((r) {
          final t = Map<String, dynamic>.from(r);
          final c = (t['category'] ?? '').toString();
          return [
            idBadge(_safe(t['id'], fallback: '-')),
            pw.Text(_safe(t['title'],       fallback: ''), style: ts(9, _cText, bold: true)),
            pw.Text(_categoryLabel(c),                      style: ts(9, _cLight)),
            pw.Text(_safe(t['description'], fallback: ''), style: ts(9, _cLight)),
          ] as List<pw.Widget>;
        }).toList(),
      ));
    }
    addPage(pageCard(reqChildren));

    // ── 4. INTERFACES EXTERNAS ───────────────────────────────────────────────
    addPage(pageCard([
      secHeading('4', 'Interfaces Externas'),
      subHeading('4.1', 'Interfaces de Usuario', first: true),
      docP(_safe(extInterfaces['user'])),
      subHeading('4.2', 'Interfaces de Hardware'),
      docP(_safe(extInterfaces['hardware'])),
      subHeading('4.3', 'Interfaces de Software'),
      docP(_safe(extInterfaces['software'])),
      subHeading('4.4', 'Interfaces de Comunicaciones'),
      docP(_safe(extInterfaces['communications'])),
    ]));

    // ── 5. APÉNDICES ─────────────────────────────────────────────────────────
    if (appendices.isNotEmpty) {
      final apChildren = <pw.Widget>[secHeading('5', 'Apéndices')];
      for (int i = 0; i < appendices.length; i++) {
        final a = Map<String, dynamic>.from(appendices[i]);
        final letter = String.fromCharCode(65 + i);
        apChildren.add(subHeading(
          '$letter.',
          _safe(a['title'], fallback: 'Apéndice ${i + 1}'),
          first: i == 0,
        ));
        apChildren.add(docP(_safe(a['content'])));
      }
      addPage(pageCard(apChildren));
    }

    return doc.save();
  }
}
