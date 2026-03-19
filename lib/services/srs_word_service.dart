import 'dart:io';

import 'package:docs_gee/docs_gee.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class SrsWordService {
  static String _safe(dynamic v, {String fallback = 'Sin información'}) {
    if (v == null) return fallback;
    final t = v.toString().trim();
    return t.isEmpty ? fallback : t;
  }

  static Future<String?> generateAndOpen(
    Map<String, dynamic> responseData,
  ) async {
    try {
      final srs = Map<String, dynamic>.from(responseData['srs_data'] ?? {});
      final meta = Map<String, dynamic>.from(srs['metadata'] ?? {});
      final intro = Map<String, dynamic>.from(srs['introduction'] ?? {});
      final overall = Map<String, dynamic>.from(
        srs['overallDescription'] ?? {},
      );
      final specific = Map<String, dynamic>.from(
        srs['specificRequirements'] ?? {},
      );

      final projectName = _safe(meta['projectName']);
      final version = _safe(responseData['version'], fallback: '1.0');
      final date = _safe(meta['createdAt']);
      final author = _safe(meta['owner']);
      final org = _safe(meta['organization']);

      final doc = Document(title: projectName, author: author);

      // PORTADA
      doc.addParagraph(Paragraph(
        runs: [
          TextRun(
            'ESPECIFICACI�N DE REQUISITOS DE SOFTWARE',
            bold: true,
            color: '1F3864',
          ),
        ],
        alignment: Alignment.center,
      ));
      doc.addParagraph(Paragraph(
        runs: [TextRun('IEEE Std 830', color: '2E5197')],
        alignment: Alignment.center,
      ));
      doc.addParagraph(Paragraph.text(''));

      doc.addTable(Table(
        borders: TableBorders.all(),
        rows: [
          TableRow(cells: [
            TableCell.text('Proyecto', backgroundColor: 'D6E4F0'),
            TableCell.text(projectName),
          ]),
          TableRow(cells: [
            TableCell.text('Versi�n', backgroundColor: 'D6E4F0'),
            TableCell.text(version),
          ]),
          TableRow(cells: [
            TableCell.text('Fecha', backgroundColor: 'D6E4F0'),
            TableCell.text(date),
          ]),
          TableRow(cells: [
            TableCell.text('Autor(es)', backgroundColor: 'D6E4F0'),
            TableCell.text(author),
          ]),
          TableRow(cells: [
            TableCell.text('Organizaci�n', backgroundColor: 'D6E4F0'),
            TableCell.text(org),
          ]),
        ],
      ));

      // 1. INTRODUCCI�N
      doc.addParagraph(
        Paragraph.heading('1. Introducci�n', level: 1, pageBreakBefore: true),
      );
      doc.addParagraph(Paragraph.heading('1.1 Prop�sito', level: 2));
      doc.addParagraph(Paragraph.text(_safe(intro['purpose'])));
      doc.addParagraph(Paragraph.heading('1.2 Alcance', level: 2));
      doc.addParagraph(Paragraph.text(_safe(intro['scope'])));
      doc.addParagraph(
        Paragraph.heading(
          '1.3 Definiciones, Acr�nimos y Abreviaturas',
          level: 2,
        ),
      );
      _addDefinitions(doc, List.from(intro['definitions'] ?? []));
      doc.addParagraph(Paragraph.heading('1.4 Referencias', level: 2));
      _addBullets(
        doc,
        List.from(intro['references'] ?? []),
        empty: 'Sin referencias registradas',
      );
      doc.addParagraph(Paragraph.heading('1.5 Visi�n General', level: 2));
      doc.addParagraph(Paragraph.text(_safe(intro['overview'])));

      // 2. DESCRIPCI�N GENERAL
      doc.addParagraph(
        Paragraph.heading(
          '2. Descripci�n General',
          level: 1,
          pageBreakBefore: true,
        ),
      );
      doc.addParagraph(
        Paragraph.heading('2.1 Perspectiva del Producto', level: 2),
      );
      doc.addParagraph(Paragraph.text(_safe(overall['productPerspective'])));
      doc.addParagraph(
        Paragraph.heading('2.2 Funciones del Producto', level: 2),
      );
      doc.addParagraph(Paragraph.text(_safe(overall['productFunctions'])));
      doc.addParagraph(Paragraph.heading('2.3 Clases de Usuario', level: 2));
      _addUserClasses(doc, List.from(overall['userClasses'] ?? []));
      doc.addParagraph(Paragraph.heading('2.4 Entorno Operativo', level: 2));
      doc.addParagraph(
        Paragraph.text(_safe(overall['operatingEnvironment'])),
      );
      doc.addParagraph(Paragraph.heading('2.5 Restricciones', level: 2));
      doc.addParagraph(Paragraph.text(_safe(overall['constraints'])));
      doc.addParagraph(
        Paragraph.heading('2.6 Suposiciones y Dependencias', level: 2),
      );
      doc.addParagraph(Paragraph.text(_safe(overall['assumptions'])));

      // 3. REQUISITOS ESPEC�FICOS
      doc.addParagraph(
        Paragraph.heading(
          '3. Requisitos Espec�ficos',
          level: 1,
          pageBreakBefore: true,
        ),
      );
      doc.addParagraph(
        Paragraph.heading('3.1 Interfaces Externas', level: 2),
      );
      doc.addParagraph(Paragraph.text(_safe(specific['externalInterfaces'])));
      doc.addParagraph(
        Paragraph.heading('3.2 Requisitos Funcionales', level: 2),
      );
      _addBullets(
        doc,
        List.from(specific['functionalRequirements'] ?? []),
        empty: 'Sin requisitos funcionales registrados',
      );
      doc.addParagraph(
        Paragraph.heading('3.3 Requisitos No Funcionales', level: 2),
      );
      _addBullets(
        doc,
        List.from(specific['nonFunctionalRequirements'] ?? []),
        empty: 'Sin requisitos no funcionales registrados',
      );
      doc.addParagraph(Paragraph.heading('3.4 Reglas de Negocio', level: 2));
      _addBullets(
        doc,
        List.from(specific['businessRules'] ?? []),
        empty: 'Sin reglas de negocio registradas',
      );
      doc.addParagraph(Paragraph.heading('3.5 Casos de Uso', level: 2));
      _addBullets(
        doc,
        List.from(specific['useCases'] ?? []),
        empty: 'Sin casos de uso registrados',
      );

      doc.addParagraph(Paragraph.text(''));
      doc.addParagraph(Paragraph(
        runs: [
          TextRun('Documento generado por FSD  �  v$version', color: '999999'),
        ],
        alignment: Alignment.center,
      ));

      final bytes = DocxGenerator().generate(doc);
      final dir = await getTemporaryDirectory();
      final safeName = projectName
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final file = File('${dir.path}/SRS_$safeName.docx');
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        return 'No se encontr� una app para abrir .docx: ${result.message}';
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static void _addBullets(
    Document doc,
    List items, {
    String empty = 'Sin información',
  }) {
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
          TextRun('${_safe(m['term'], fallback: '')}: ', bold: true),
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
      doc.addParagraph(Paragraph(
        runs: [
          TextRun('ID: ', bold: true),
          TextRun(_safe(m['id'])),
        ],
      ));
      doc.addParagraph(Paragraph(
        runs: [
          TextRun('Descripción: ', bold: true),
          TextRun(_safe(m['description'])),
        ],
      ));
      doc.addParagraph(Paragraph(
        runs: [
          TextRun('Caracter�sticas: ', bold: true),
          TextRun(_safe(m['characteristics'])),
        ],
      ));
    }
  }
}
