content = """\
import 'dart:io';

import 'package:docs_gee/docs_gee.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class SrsWordService {
  // ── helpers ────────────────────────────────────────────────────────────────
  static String _safe(dynamic v, {String fallback = 'Sin información'}) {
    if (v == null) return fallback;
    final t = v.toString().trim();
    return t.isEmpty ? fallback : t;
  }

  static String _priorityLabel(String p) {
    switch (p.trim().toLowerCase()) {
      case 'high':   return 'ALTA';
      case 'medium': return 'MEDIA';
      case 'low':    return 'BAJA';
      default:       return p.toUpperCase();
    }
  }

  static String _categoryLabel(String c) {
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

  // ── public entry point ─────────────────────────────────────────────────────
  static Future<String?> generateAndOpen(
    Map<String, dynamic> responseData,
  ) async {
    try {
      final srs              = Map<String, dynamic>.from(responseData['srs_data']        ?? {});
      final meta             = Map<String, dynamic>.from(srs['metadata']                 ?? {});
      final intro            = Map<String, dynamic>.from(srs['introduction']             ?? {});
      final overall          = Map<String, dynamic>.from(srs['overallDescription']       ?? {});
      final requirements     = Map<String, dynamic>.from(srs['requirements']             ?? {});
      final extInterfaces    = Map<String, dynamic>.from(srs['externalInterfaces']       ?? {});
      final appendices       = List.from(srs['appendices']      ?? []);
      final teamMembers      = List.from(srs['teamMembers']     ?? []);
      final revisionHistory  = List.from(srs['revisionHistory'] ?? []);
      final approvalHistory  = List.from(srs['approvalHistory'] ?? []);
      final functionalReqs   = List.from(requirements['functional']    ?? []);
      final nonFunctionalReqs= List.from(requirements['nonFunctional'] ?? []);
      final defs             = List.from(intro['definitions'] ?? []);
      final refs             = List.from(intro['references']  ?? []);
      final userClasses      = List.from(overall['userClasses'] ?? []);

      final projectName = _safe(meta['projectName']);
      final version     = _safe(responseData['version'], fallback: '1.0');
      final date        = _safe(meta['createdAt']);
      final owner       = _safe(meta['owner']);
      final org         = _safe(meta['organization']);
      final projectCode = _safe(meta['projectCode'], fallback: '');
      final statusRaw   = (meta['status'] ?? '').toString().trim();
      const statusLabels = {
        'draft':     'Borrador',
        'in_review': 'En Revisión',
        'approved':  'Aprobado',
        'archived':  'Archivado',
      };
      final statusDisplay = statusLabels[statusRaw] ?? statusRaw;

      final doc = Document(title: projectName, author: owner);

      // ── PORTADA ──────────────────────────────────────────────────────────
      doc.addParagraph(Paragraph(
        runs: [TextRun('DOCUMENTO TÉCNICO', bold: true, color: '94A3B8')],
        alignment: Alignment.center,
      ));
      doc.addParagraph(Paragraph(
        runs: [TextRun(projectName, bold: true, fontSize: 32, color: '1A202C')],
        alignment: Alignment.center,
      ));
      doc.addParagraph(Paragraph(
        runs: [TextRun('Especificación de Requisitos de Software',
            color: '94A3B8', italic: true)],
        alignment: Alignment.center,
      ));
      doc.addParagraph(Paragraph.text(''));

      final metaRows = <TableRow>[];
      void addMetaRow(String label, String value) {
        if (value.isEmpty || value == 'Sin información') return;
        metaRows.add(TableRow(cells: [
          TableCell.text(label, backgroundColor: 'F8FAFC'),
          TableCell.text(value),
        ]));
      }
      addMetaRow('CÓDIGO DEL PROYECTO', projectCode);
      addMetaRow('VERSIÓN', version);
      addMetaRow('FECHA', date);
      addMetaRow('ESTADO', statusDisplay);
      addMetaRow('PROPIETARIO', owner);
      addMetaRow('ORGANIZACIÓN', org);
      if (metaRows.isNotEmpty) {
        doc.addTable(Table(borders: TableBorders.all(), rows: metaRows));
      }

      if (teamMembers.isNotEmpty) {
        doc.addParagraph(Paragraph.text(''));
        doc.addParagraph(Paragraph(
          runs: [TextRun('MIEMBROS DEL EQUIPO', bold: true, color: '64748B')],
        ));
        doc.addTable(Table(
          borders: TableBorders.all(),
          rows: [
            TableRow(cells: [
              TableCell.text('NOMBRE', backgroundColor: 'F8FAFC'),
              TableCell.text('ROL',    backgroundColor: 'F8FAFC'),
              TableCell.text('EMAIL',  backgroundColor: 'F8FAFC'),
            ]),
            ...teamMembers.map((m) {
              final t = Map<String, dynamic>.from(m);
              return TableRow(cells: [
                TableCell.text(_safe(t['name'],  fallback: '')),
                TableCell.text(_safe(t['role'],  fallback: '')),
                TableCell.text(_safe(t['email'], fallback: '')),
              ]);
            }),
          ],
        ));
      }

      // ── HISTORIAL ────────────────────────────────────────────────────────
      if (revisionHistory.isNotEmpty || approvalHistory.isNotEmpty) {
        doc.addParagraph(Paragraph.heading(
          'Historial de Revisiones y Aprobaciones',
          level: 1, pageBreakBefore: true,
        ));
        if (revisionHistory.isNotEmpty) {
          doc.addParagraph(Paragraph.heading('Historial de Revisiones', level: 2));
          doc.addTable(Table(
            borders: TableBorders.all(),
            rows: [
              TableRow(cells: [
                TableCell.text('VERSIÓN',     backgroundColor: 'F8FAFC'),
                TableCell.text('FECHA',       backgroundColor: 'F8FAFC'),
                TableCell.text('DESCRIPCIÓN', backgroundColor: 'F8FAFC'),
                TableCell.text('AUTOR',       backgroundColor: 'F8FAFC'),
              ]),
              ...revisionHistory.map((r) {
                final t = Map<String, dynamic>.from(r);
                return TableRow(cells: [
                  TableCell.text(_safe(t['version'],     fallback: '')),
                  TableCell.text(_safe(t['date'],        fallback: '')),
                  TableCell.text(_safe(t['description'], fallback: '')),
                  TableCell.text(_safe(t['author'],      fallback: '')),
                ]);
              }),
            ],
          ));
        }
        if (approvalHistory.isNotEmpty) {
          doc.addParagraph(Paragraph.heading('Historial de Aprobaciones', level: 2));
          doc.addTable(Table(
            borders: TableBorders.all(),
            rows: [
              TableRow(cells: [
                TableCell.text('ROL',    backgroundColor: 'F8FAFC'),
                TableCell.text('NOMBRE', backgroundColor: 'F8FAFC'),
                TableCell.text('FECHA',  backgroundColor: 'F8FAFC'),
                TableCell.text('FIRMA',  backgroundColor: 'F8FAFC'),
              ]),
              ...approvalHistory.map((a) {
                final t = Map<String, dynamic>.from(a);
                return TableRow(cells: [
                  TableCell.text(_safe(t['role'],      fallback: '')),
                  TableCell.text(_safe(t['name'],      fallback: '')),
                  TableCell.text(_safe(t['date'],      fallback: '')),
                  TableCell.text(_safe(t['signature'], fallback: '')),
                ]);
              }),
            ],
          ));
        }
      }

      // ── 1. INTRODUCCIÓN ─────────────────────────────────────────────────
      doc.addParagraph(Paragraph.heading('1. Introducción',
          level: 1, pageBreakBefore: true));
      doc.addParagraph(Paragraph.heading('1.1 Propósito', level: 2));
      doc.addParagraph(Paragraph.text(_safe(intro['purpose'])));
      doc.addParagraph(Paragraph.heading('1.2 Alcance', level: 2));
      doc.addParagraph(Paragraph.text(_safe(intro['scope'])));
      if (defs.isNotEmpty) {
        doc.addParagraph(Paragraph.heading(
            '1.3 Definiciones, Acrónimos y Abreviaturas', level: 2));
        _addDefinitions(doc, defs);
      }
      if (refs.isNotEmpty) {
        doc.addParagraph(Paragraph.heading('1.4 Referencias', level: 2));
        _addBullets(doc, refs, empty: 'Sin referencias registradas');
      }
      final overview = (intro['overview'] ?? '').toString().trim();
      if (overview.isNotEmpty) {
        doc.addParagraph(Paragraph.heading('1.5 Visión General', level: 2));
        doc.addParagraph(Paragraph.text(overview));
      }

      // ── 2. DESCRIPCIÓN GENERAL ──────────────────────────────────────────
      doc.addParagraph(Paragraph.heading('2. Descripción General',
          level: 1, pageBreakBefore: true));
      doc.addParagraph(Paragraph.heading('2.1 Perspectiva del Producto', level: 2));
      doc.addParagraph(Paragraph.text(_safe(overall['productPerspective'])));
      doc.addParagraph(Paragraph.heading('2.2 Funciones del Producto', level: 2));
      doc.addParagraph(Paragraph.text(_safe(overall['productFunctions'])));
      if (userClasses.isNotEmpty) {
        doc.addParagraph(Paragraph.heading('2.3 Clases de Usuario', level: 2));
        _addUserClasses(doc, userClasses);
      }
      doc.addParagraph(Paragraph.heading('2.4 Entorno Operativo', level: 2));
      doc.addParagraph(Paragraph.text(_safe(overall['operatingEnvironment'])));
      doc.addParagraph(Paragraph.heading(
          '2.5 Restricciones de Diseño e Implementación', level: 2));
      doc.addParagraph(Paragraph.text(_safe(overall['constraints'])));
      doc.addParagraph(
          Paragraph.heading('2.6 Suposiciones y Dependencias', level: 2));
      doc.addParagraph(Paragraph.text(_safe(overall['assumptions'])));

      // ── 3. REQUISITOS ESPECÍFICOS ────────────────────────────────────────
      doc.addParagraph(Paragraph.heading('3. Requisitos Específicos',
          level: 1, pageBreakBefore: true));

      doc.addParagraph(Paragraph.heading('3.1 Requisitos Funcionales', level: 2));
      if (functionalReqs.isEmpty) {
        doc.addParagraph(
            Paragraph.text('Sin requisitos funcionales registrados'));
      } else {
        doc.addTable(Table(
          borders: TableBorders.all(),
          rows: [
            TableRow(cells: [
              TableCell.text('ID',          backgroundColor: 'F8FAFC'),
              TableCell.text('TÍTULO',      backgroundColor: 'F8FAFC'),
              TableCell.text('PRIORIDAD',   backgroundColor: 'F8FAFC'),
              TableCell.text('DESCRIPCIÓN', backgroundColor: 'F8FAFC'),
            ]),
            ...functionalReqs.map((r) {
              final t = Map<String, dynamic>.from(r);
              final p = (t['priority'] ?? '').toString();
              return TableRow(cells: [
                TableCell.text(_safe(t['id'],          fallback: '')),
                TableCell.text(_safe(t['title'],       fallback: '')),
                TableCell.text(_priorityLabel(p)),
                TableCell.text(_safe(t['description'], fallback: '')),
              ]);
            }),
          ],
        ));
      }

      doc.addParagraph(
          Paragraph.heading('3.2 Requisitos No Funcionales', level: 2));
      if (nonFunctionalReqs.isEmpty) {
        doc.addParagraph(
            Paragraph.text('Sin requisitos no funcionales registrados'));
      } else {
        doc.addTable(Table(
          borders: TableBorders.all(),
          rows: [
            TableRow(cells: [
              TableCell.text('ID',          backgroundColor: 'F8FAFC'),
              TableCell.text('TÍTULO',      backgroundColor: 'F8FAFC'),
              TableCell.text('CATEGORÍA',   backgroundColor: 'F8FAFC'),
              TableCell.text('DESCRIPCIÓN', backgroundColor: 'F8FAFC'),
            ]),
            ...nonFunctionalReqs.map((r) {
              final t = Map<String, dynamic>.from(r);
              final c = (t['category'] ?? '').toString();
              return TableRow(cells: [
                TableCell.text(_safe(t['id'],          fallback: '')),
                TableCell.text(_safe(t['title'],       fallback: '')),
                TableCell.text(_categoryLabel(c)),
                TableCell.text(_safe(t['description'], fallback: '')),
              ]);
            }),
          ],
        ));
      }

      // ── 4. INTERFACES EXTERNAS ───────────────────────────────────────────
      doc.addParagraph(Paragraph.heading('4. Interfaces Externas',
          level: 1, pageBreakBefore: true));
      doc.addParagraph(Paragraph.heading('4.1 Interfaces de Usuario', level: 2));
      doc.addParagraph(Paragraph.text(_safe(extInterfaces['user'])));
      doc.addParagraph(Paragraph.heading('4.2 Interfaces de Hardware', level: 2));
      doc.addParagraph(Paragraph.text(_safe(extInterfaces['hardware'])));
      doc.addParagraph(Paragraph.heading('4.3 Interfaces de Software', level: 2));
      doc.addParagraph(Paragraph.text(_safe(extInterfaces['software'])));
      doc.addParagraph(
          Paragraph.heading('4.4 Interfaces de Comunicaciones', level: 2));
      doc.addParagraph(Paragraph.text(_safe(extInterfaces['communications'])));

      // ── 5. APÉNDICES ────────────────────────────────────────────────────
      if (appendices.isNotEmpty) {
        doc.addParagraph(Paragraph.heading('5. Apéndices',
            level: 1, pageBreakBefore: true));
        for (int i = 0; i < appendices.length; i++) {
          final a = Map<String, dynamic>.from(appendices[i]);
          final letter = String.fromCharCode(65 + i);
          doc.addParagraph(Paragraph.heading(
            '$letter. ${_safe(a[\\'title\\'], fallback: \\'Apéndice ${i + 1}\\')}',
            level: 2,
          ));
          doc.addParagraph(Paragraph.text(_safe(a['content'])));
        }
      }

      // ── Footer ───────────────────────────────────────────────────────────
      doc.addParagraph(Paragraph.text(''));
      doc.addParagraph(Paragraph(
        runs: [
          TextRun('Documento generado por FSD  ·  v$version', color: '94A3B8')
        ],
        alignment: Alignment.center,
      ));

      // ── Save & open ──────────────────────────────────────────────────────
      final bytes = DocxGenerator().generate(doc);
      final dir = await getTemporaryDirectory();
      final safeName = projectName
          .replaceAll(RegExp(r'[^\\w\\s]'), '')
          .trim()
          .replaceAll(RegExp(r'\\s+'), '_');
      final file = File('\${dir.path}/SRS_\$safeName.docx');
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        return 'No se encontró una app para abrir .docx: \${result.message}';
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── private helpers ────────────────────────────────────────────────────────

  static void _addBullets(Document doc, List items,
      {String empty = 'Sin información'}) {
    if (items.isEmpty) {
      doc.addParagraph(Paragraph.text(empty));
      return;
    }
    for (final item in items) {
      doc.addParagraph(Paragraph.bulletItem(item.toString()));
    }
  }

  static void _addDefinitions(Document doc, List items) {
    if (items.isEmpty) {
      doc.addParagraph(Paragraph.text('Sin información'));
      return;
    }
    for (final d in items) {
      final m = Map<String, dynamic>.from(d);
      doc.addParagraph(Paragraph(
        runs: [
          TextRun('\${_safe(m[\\'term\\'], fallback: \\'\\')}:  ', bold: true),
          TextRun(_safe(m['definition'], fallback: '')),
        ],
      ));
    }
  }

  static void _addUserClasses(Document doc, List items) {
    if (items.isEmpty) {
      doc.addParagraph(Paragraph.text('Sin clases de usuario registradas'));
      return;
    }
    for (final u in items) {
      final m = Map<String, dynamic>.from(u);
      doc.addParagraph(Paragraph(
        runs: [TextRun(_safe(m['name'], fallback: 'Usuario'), bold: true)],
      ));
      if (_safe(m['description'], fallback: '').isNotEmpty) {
        doc.addParagraph(Paragraph(
          runs: [
            TextRun('Descripción: ', bold: true),
            TextRun(_safe(m['description'])),
          ],
        ));
      }
      if (_safe(m['characteristics'], fallback: '').isNotEmpty) {
        doc.addParagraph(Paragraph(
          runs: [
            TextRun('Características: ', bold: true),
            TextRun(_safe(m['characteristics'])),
          ],
        ));
      }
    }
  }
}
"""

with open(
    r"C:\Users\PC PRIDE WHITE WOLF\Desktop\fsdmovil\lib\services\srs_word_service.dart",
    "w",
    encoding="utf-8",
) as f:
    f.write(content)

print("written ok")
