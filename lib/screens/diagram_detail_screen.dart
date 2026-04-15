import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';

const _diagramTypeMap = <String, String>{
  'use-case':  'Caso de uso',
  'sequence':  'Secuencia',
  'class':     'Clase',
  'activity':  'Actividad',
  'er':        'Diagrama ER',
  'flowchart': 'Flujo',
  'state':     'Estado',
  'mr':        'Modelo Relacional',
};

// Types that support the interactive (cytoscape) visual editor
const _interactiveTypes = {
  'flowchart', 'use-case', 'activity', 'state',
  'class', 'sequence', 'er', 'mr',
};

enum _ViewMode { visual, code }

/// Top-bar tab selection for this screen
enum _DiagramViewMode { formulario, json, ai }

class DiagramDetailScreen extends StatefulWidget {
  final int diagramId;
  const DiagramDetailScreen({super.key, required this.diagramId});

  @override
  State<DiagramDetailScreen> createState() => _DiagramDetailScreenState();
}

class _DiagramDetailScreenState extends State<DiagramDetailScreen> {
  bool loading = true;
  String? errorMessage;
  Map<String, dynamic>? diagram;

  // Code editor state
  late TextEditingController _codeController;
  String _initialCode = '';
  bool _isSaving = false;
  bool _previewLoading = true;
  bool _interactiveLoading = true;
  bool _bottomPanelOpen = false;
  bool _edgeModeActive = false;
  _ViewMode _viewMode = _ViewMode.visual;
  _DiagramViewMode _diagViewMode = _DiagramViewMode.json;

  late final WebViewController _webViewController;
  late final WebViewController _interactiveController;

  bool get _isDirty => _codeController.text != _initialCode;

  bool get _isInteractiveType {
    final d = diagram;
    if (d == null) return false;
    final t = (d['diagram_type'] ?? d['type'] ?? '').toString().toLowerCase();
    return _interactiveTypes.contains(t);
  }

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _codeController.addListener(_onCodeChanged);
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _previewLoading = false);
        },
      ));
    _interactiveController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (msg) => _onInteractiveCodeChanged(msg.message),
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _interactiveLoading = false);
        },
      ));
    _load();
  }

  void _onCodeChanged() {
    if (mounted) setState(() {});
  }

  String _buildHtml(String code) {
    return '''<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: #0F1017;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
    padding: 16px;
    overflow-x: hidden;
  }
  .mermaid svg { max-width: 100% !important; height: auto !important; }
  #err { color: #E8365D; font-family: monospace; font-size: 13px; white-space: pre-wrap; padding: 12px; }
</style>
</head>
<body>
<div class="mermaid" id="diagram">$code</div>
<div id="err"></div>
<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
<script>
  mermaid.initialize({
    startOnLoad: false,
    theme: 'dark',
    securityLevel: 'loose',
    themeVariables: { background: '#0F1017', primaryColor: '#E8365D' }
  });
  mermaid.run({ nodes: [document.getElementById("diagram")] })
    .catch(function(e) {
      document.getElementById("err").textContent = "Error: " + e.message;
    });
</script>
</body>
</html>''';
  }

  void _refreshPreview() {
    setState(() => _previewLoading = true);
    _webViewController.loadHtmlString(_buildHtml(_codeController.text));
  }

  void _refreshInteractive() {
    setState(() => _interactiveLoading = true);
    _interactiveController.loadHtmlString(
      _buildInteractiveHtml(_codeController.text),
    );
  }

  void _onInteractiveCodeChanged(String newCode) {
    if (newCode.startsWith('__rename:')) {
      final parts = newCode.substring(9).split(':');
      final nodeId = parts[0];
      final currentLabel = parts.length > 1 ? parts.sublist(1).join(':') : '';
      _showNodeRenameDialog(nodeId, currentLabel);
      return;
    }
    if (newCode == _codeController.text) return;
    _codeController.removeListener(_onCodeChanged);
    _codeController.text = newCode;
    _codeController.addListener(_onCodeChanged);
    if (mounted) setState(() {});
  }

  Future<void> _showNodeRenameDialog(String nodeId, String currentLabel) async {
    final controller = TextEditingController(text: currentLabel);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2130),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Renombrar nodo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: fsdPink,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF252838),
            hintText: 'Nombre del nodo',
            hintStyle: const TextStyle(color: fsdTextGrey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: fsdBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: fsdBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: fsdPink),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: fsdTextGrey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: fsdPink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (newLabel != null && newLabel.isNotEmpty) {
      final safe = newLabel.replaceAll("'", "\\'");
      _interactiveController.runJavaScript("renameNode('$nodeId','$safe')");
    }
  }

  /// Cytoscape-based interactive editor for flow/use_case/activity/state diagrams.
  /// Parses basic Mermaid graph syntax and allows drag-to-rearrange + add/remove nodes+edges.
  String _buildInteractiveHtml(String code) {
    // Escape for JS backtick-string embedding
    final escaped = code
        .replaceAll(r'\', r'\\')
        .replaceAll('`', r'\`')
        .replaceAll(r'$', r'\$');

    const head = r'''<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { background: #0F1017; color: #CDD3DE; font-family: -apple-system, sans-serif; overflow: hidden; }
#cy { width: 100vw; height: 100vh; }
</style>
</head>
<body>
<div id="cy"></div>
<script src="https://cdn.jsdelivr.net/npm/cytoscape@3.28.1/dist/cytoscape.min.js"></script>
<script>
var edgeMode = false, edgeSource = null, nodeCounter = 0;
function parseMermaid(code) {
  var nodes = {}, edges = [];
  var lines = code.split('\n');
  lines = lines.filter(function(l) {
    return !l.trim().match(new RegExp('^(graph|flowchart|stateDiagram|sequenceDiagram|classDiagram|erDiagram|activityDiagram)','i'));
  });
  function cleanId(s) {
    s = s.trim().replace(/^["']|["']$/g,'');
    var m = s.match(/^(\w+)[\[\(\{]/);
    return m ? m[1] : s.trim() || s;
  }
  function cleanLabel(s) {
    s = s.trim();
    var m = s.match(/^\w+[\[\(\{>]([^\]\)\}]*)[\]\)\}]$/);
    if (m) return m[1];
    m = s.match(/^["'](.*)["']$/);
    if (m) return m[1];
    return cleanId(s);
  }
  function ensureNode(raw) {
    var id = cleanId(raw);
    if (!nodes[id]) nodes[id] = cleanLabel(raw);
    return id;
  }
  lines.forEach(function(line) {
    line = line.trim();
    if (!line || line.indexOf('%%') === 0) return;
    var arrowIdx = line.indexOf('-->');
    if (arrowIdx === -1) arrowIdx = line.indexOf('->');
    if (arrowIdx !== -1) {
      var lm = line.match(/-->\|([^|]*)\|/);
      var eLabel = lm ? lm[1] : '';
      var rest = line;
      var parts = [];
      var chunk = '';
      var i = 0;
      while (i < rest.length) {
        if (rest.substr(i,3) === '-->') { parts.push(chunk.trim()); chunk = ''; i += 3; if(rest[i]==='|'){var e=rest.indexOf('|',i+1);if(e!==-1){eLabel=rest.substring(i+1,e);i=e+1;}} }
        else if (rest.substr(i,2) === '->') { parts.push(chunk.trim()); chunk = ''; i += 2; }
        else { chunk += rest[i]; i++; }
      }
      parts.push(chunk.trim());
      if (parts.length >= 2) {
        var src = ensureNode(parts[0]);
        for (var j = 1; j < parts.length; j++) {
          if (!parts[j]) continue;
          var tgt = ensureNode(parts[j]);
          edges.push({ source: src, target: tgt, label: eLabel });
          src = tgt; eLabel = '';
        }
      }
    } else {
      ensureNode(line);
    }
    nodeCounter = Math.max(nodeCounter, Object.keys(nodes).length);
  });
  return { nodes: nodes, edges: edges };
}
var initialCode = `''';

    const tail = r'''`;
var parsed = parseMermaid(initialCode);
var cyElements = [];
Object.keys(parsed.nodes).forEach(function(id) {
  cyElements.push({ data: { id: id, label: parsed.nodes[id] || id } });
});
parsed.edges.forEach(function(e, i) {
  cyElements.push({ data: { id: 'e'+i, source: e.source, target: e.target, label: e.label } });
});
var cy = cytoscape({
  container: document.getElementById('cy'),
  elements: cyElements,
  style: [
    { selector: 'node', style: {
        'background-color': '#2C2C3E', 'border-width': 2, 'border-color': '#3A3A3C',
        'color': '#CDD3DE', 'label': 'data(label)', 'font-size': '13px',
        'text-valign': 'center', 'text-halign': 'center',
        'width': 'label', 'height': 'label', 'padding': '10px',
        'shape': 'roundrectangle', 'text-wrap': 'wrap', 'text-max-width': '120px' } },
    { selector: 'node:selected', style: { 'border-color': '#E8365D', 'border-width': 2.5, 'background-color': '#E8365D22' } },
    { selector: 'node.edge-source', style: { 'border-color': '#55A6FF', 'border-width': 2.5, 'background-color': '#55A6FF22' } },
    { selector: 'edge', style: {
        'width': 2, 'line-color': '#3A3A3C', 'target-arrow-color': '#3A3A3C',
        'target-arrow-shape': 'triangle', 'curve-style': 'bezier',
        'label': 'data(label)', 'font-size': '11px', 'color': '#8E8E93',
        'text-background-color': '#0F1017', 'text-background-opacity': 1, 'text-background-padding': '3px' } },
    { selector: 'edge:selected', style: { 'line-color': '#E8365D', 'target-arrow-color': '#E8365D' } },
    { selector: 'node.decision', style: { 'shape': 'diamond', 'padding': '16px' } },
    { selector: 'node.start', style: { 'shape': 'ellipse', 'background-color': '#E8365D', 'border-color': '#E8365D', 'color': '#fff' } },
    { selector: 'node.end', style: { 'shape': 'ellipse', 'background-color': '#1BC47D', 'border-color': '#1BC47D', 'color': '#fff' } },
    { selector: 'node.note', style: { 'shape': 'rectangle', 'background-color': '#F2A91D22', 'border-color': '#F2A91D', 'color': '#F2A91D' } },
    { selector: 'node.actor', style: { 'shape': 'ellipse', 'background-color': '#FF9800', 'border-color': '#FF9800', 'color': '#fff' } },
    { selector: 'node.usecase', style: { 'shape': 'ellipse', 'background-color': '#55A6FF22', 'border-color': '#55A6FF', 'color': '#CDD3DE' } },
    { selector: 'node.boundary', style: { 'shape': 'rectangle', 'background-color': '#1E2130', 'border-color': '#55A6FF', 'border-style': 'dashed', 'border-width': 2, 'color': '#CDD3DE' } },
    { selector: 'node.interface-cls', style: { 'shape': 'rectangle', 'background-color': '#1E2130', 'border-color': '#9B59B6', 'border-style': 'dashed', 'border-width': 2, 'color': '#9B59B6' } },
    { selector: 'node.abstract-cls', style: { 'shape': 'roundrectangle', 'background-color': '#2C2C3E', 'border-color': '#E8365D', 'border-width': 2, 'color': '#E8365D' } },
    { selector: 'node.er-attr', style: { 'shape': 'ellipse', 'background-color': '#1E2130', 'border-color': '#1BC47D', 'color': '#1BC47D', 'padding': '6px' } },
    { selector: 'node.er-weak', style: { 'shape': 'rectangle', 'background-color': '#1E2130', 'border-color': '#F2A91D', 'border-style': 'dashed', 'border-width': 2, 'color': '#F2A91D' } },
    { selector: 'node.fork-join', style: { 'shape': 'rectangle', 'background-color': '#CDD3DE', 'border-color': '#CDD3DE', 'height': '14px', 'color': '#0F1017', 'font-size': '8px' } },
    { selector: 'node.composite', style: { 'shape': 'roundrectangle', 'background-color': '#1A1A2E', 'border-color': '#55A6FF', 'border-width': 2, 'color': '#CDD3DE' } },
    { selector: 'node.table-node', style: { 'shape': 'rectangle', 'background-color': '#1E2130', 'border-color': '#E8365D', 'border-width': 2, 'color': '#CDD3DE' } },
    { selector: 'node.pk-field', style: { 'shape': 'roundrectangle', 'background-color': '#E8365D22', 'border-color': '#E8365D', 'color': '#E8365D', 'padding': '8px' } },
    { selector: 'node.fk-field', style: { 'shape': 'roundrectangle', 'background-color': '#55A6FF22', 'border-color': '#55A6FF', 'color': '#55A6FF', 'padding': '8px' } },
    { selector: 'node.seq-actor', style: { 'shape': 'ellipse', 'background-color': '#FF9800', 'border-color': '#FF9800', 'color': '#fff' } },
    { selector: 'node.seq-obj', style: { 'shape': 'rectangle', 'background-color': '#2C2C3E', 'border-color': '#55A6FF', 'border-width': 2, 'color': '#CDD3DE' } },
    { selector: 'node.fragment', style: { 'shape': 'rectangle', 'background-color': '#1BC47D11', 'border-color': '#1BC47D', 'border-style': 'dashed', 'color': '#1BC47D' } },
    { selector: 'edge.dashed', style: { 'line-style': 'dashed' } },
    { selector: 'edge.dotted', style: { 'line-style': 'dotted' } },
    { selector: 'edge.inheritance', style: { 'target-arrow-shape': 'triangle', 'target-arrow-fill': 'hollow', 'target-arrow-color': '#CDD3DE', 'line-color': '#3A3A3C' } },
    { selector: 'edge.composition', style: { 'source-arrow-shape': 'diamond', 'source-arrow-color': '#CDD3DE', 'line-color': '#3A3A3C', 'target-arrow-shape': 'none' } },
    { selector: 'edge.aggregation', style: { 'source-arrow-shape': 'diamond', 'source-arrow-fill': 'hollow', 'source-arrow-color': '#CDD3DE', 'line-color': '#3A3A3C', 'target-arrow-shape': 'none' } },
    { selector: 'edge.dependency', style: { 'line-style': 'dashed', 'target-arrow-shape': 'vee', 'target-arrow-color': '#8E8E93', 'line-color': '#8E8E93' } },
    { selector: 'edge.extend-rel', style: { 'line-style': 'dashed', 'target-arrow-shape': 'triangle', 'color': '#F2A91D', 'line-color': '#F2A91D', 'target-arrow-color': '#F2A91D', 'text-background-color': '#0F1017', 'text-background-opacity': 1, 'text-background-padding': '3px' } },
    { selector: 'edge.include-rel', style: { 'line-style': 'dashed', 'target-arrow-shape': 'triangle', 'color': '#55A6FF', 'line-color': '#55A6FF', 'target-arrow-color': '#55A6FF', 'text-background-color': '#0F1017', 'text-background-opacity': 1, 'text-background-padding': '3px' } },
    { selector: 'edge.assoc-line', style: { 'target-arrow-shape': 'none', 'line-color': '#3A3A3C' } },
    { selector: 'edge.one-to-one', style: { 'color': '#1BC47D', 'line-color': '#1BC47D', 'target-arrow-shape': 'none', 'text-background-color': '#0F1017', 'text-background-opacity': 1, 'text-background-padding': '3px' } },
    { selector: 'edge.one-to-many', style: { 'color': '#55A6FF', 'line-color': '#55A6FF', 'target-arrow-shape': 'none', 'text-background-color': '#0F1017', 'text-background-opacity': 1, 'text-background-padding': '3px' } },
    { selector: 'edge.many-to-many', style: { 'color': '#F2A91D', 'line-color': '#F2A91D', 'target-arrow-shape': 'none', 'text-background-color': '#0F1017', 'text-background-opacity': 1, 'text-background-padding': '3px' } }
  ],
  layout: { name: 'breadthfirst', directed: true, padding: 20, spacingFactor: 1.4 },
  userZoomingEnabled: true, userPanningEnabled: true, minZoom: 0.3, maxZoom: 3,
});
cy.on('tap', 'node', function(e) {
  if (!edgeMode) return;
  var node = e.target;
  if (!edgeSource) {
    edgeSource = node; node.addClass('edge-source');
  } else {
    if (edgeSource.id() !== node.id()) {
      cy.add({ data: { id: 'e'+Date.now(), source: edgeSource.id(), target: node.id(), label: '' } });
      emitCode();
    }
    edgeSource.removeClass('edge-source'); edgeSource = null;
  }
});
cy.on('tap', function(e) {
  if (e.target === cy && edgeMode && edgeSource) {
    edgeSource.removeClass('edge-source'); edgeSource = null;
  }
});
cy.on('dbltap', 'node', function(e) {
  if (edgeMode) return;
  var node = e.target;
  if (typeof FlutterBridge !== 'undefined') FlutterBridge.postMessage('__rename:' + node.id() + ':' + node.data('label'));
});
function renameNode(id, newLabel) {
  var n = cy.getElementById(id);
  if (!n.empty()) { n.data('label', newLabel); emitCode(); }
}
cy.on('free', 'node', function() { emitCode(); });
cy.on('remove', function() { emitCode(); });
cy.on('add', 'edge', function() { emitCode(); });
function addNode() {
  nodeCounter++;
  var id = 'N' + nodeCounter;
  cy.add({ data: { id: id, label: 'Nodo ' + nodeCounter } });
  cy.layout({ name: 'breadthfirst', directed: true, padding: 20 }).run();
  emitCode();
}
function addNodeOfType(shape, cls, defaultLabel) {
  nodeCounter++;
  var id = (cls || 'N') + nodeCounter;
  var el = { data: { id: id, label: defaultLabel || 'Nodo ' + nodeCounter } };
  if (cls) el.classes = cls;
  cy.add(el);
  cy.layout({ name: 'breadthfirst', directed: true, padding: 20 }).run();
  emitCode();
}
function addEdgeOfType(style) {
  if (cy.nodes().length < 2) { alert('Necesitas al menos 2 nodos.'); return; }
  var all = cy.nodes();
  var src = all[0].id(), tgt = all[1].id();
  var el = { data: { id: 'e' + Date.now(), source: src, target: tgt, label: '' } };
  if (style) el.classes = style;
  cy.add(el); emitCode();
}
function addEdgeLabeled(cls, lbl) {
  if (cy.nodes().length < 2) { alert('Necesitas al menos 2 nodos.'); return; }
  var all = cy.nodes();
  var src = all[0].id(), tgt = all[1].id();
  var el = { data: { id: 'e' + Date.now(), source: src, target: tgt, label: lbl } };
  if (cls) el.classes = cls;
  cy.add(el); emitCode();
}
function addSelfEdge() {
  if (cy.nodes().length < 1) { alert('Necesitas al menos 1 nodo.'); return; }
  var n = cy.nodes(':selected').first();
  if (n.empty()) n = cy.nodes().first();
  cy.add({ data: { id: 'e' + Date.now(), source: n.id(), target: n.id(), label: 'self' } });
  emitCode();
}
function fitView() { cy.fit(undefined, 20); }
function toggleEdgeMode() {
  edgeMode = !edgeMode;
  if (!edgeMode && edgeSource) { edgeSource.removeClass('edge-source'); edgeSource = null; }
}
function deleteSelected() { cy.elements(':selected').remove(); emitCode(); }
function layoutAuto() { cy.layout({ name: 'breadthfirst', directed: true, padding: 20, spacingFactor: 1.4 }).run(); }
function emitCode() {
  var lines = ['graph TD'];
  var nodeIds = {};
  cy.nodes().forEach(function(n) {
    nodeIds[n.id()] = true;
    var lbl = n.data('label') || n.id();
    lines.push(lbl === n.id() ? '  ' + n.id() : '  ' + n.id() + '["' + lbl + '"]');
  });
  cy.edges().forEach(function(e) {
    var src = e.data('source'), tgt = e.data('target'), lbl = e.data('label') || '';
    if (!nodeIds[src] || !nodeIds[tgt]) return;
    lines.push(lbl ? '  ' + src + ' -->|' + lbl + '| ' + tgt : '  ' + src + ' --> ' + tgt);
  });
  if (typeof FlutterBridge !== 'undefined') FlutterBridge.postMessage(lines.join('\n'));
}
</script></body></html>''';

    return head + escaped + tail;
  }

  Future<void> _save() async {
    if (!_isDirty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ApiService.patchDiagram(widget.diagramId, {
        'mermaid_code': _codeController.text,
      });
      if (!mounted) return;
      setState(() => _initialCode = _codeController.text);
      _refreshPreview();
      _refreshInteractive();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Error al guardar: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: fsdPink,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveManual() => _save();

  String get _diagramType {
    final d = diagram;
    if (d == null) return '';
    return (d['diagram_type'] ?? d['type'] ?? '').toString().toLowerCase().replaceAll('_', '-');
  }

  void _jsCall(String fn) => _interactiveController.runJavaScript(fn);

  Future<void> _addNode() =>
      _interactiveController.runJavaScript('addNode()');

  Future<void> _toggleEdgeMode() async {
    setState(() => _edgeModeActive = !_edgeModeActive);
    await _interactiveController.runJavaScript('toggleEdgeMode()');
  }

  Future<void> _deleteSelected() =>
      _interactiveController.runJavaScript('deleteSelected()');

  Future<void> _autoLayout() =>
      _interactiveController.runJavaScript('layoutAuto()');

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getDiagram(widget.diagramId);
      if (!mounted) return;
      final code = (data['mermaid_code'] ?? '').toString();
      _codeController.removeListener(_onCodeChanged);
      _codeController.text = code;
      _initialCode = code;
      _codeController.addListener(_onCodeChanged);
      _webViewController.loadHtmlString(_buildHtml(code));
      _interactiveController.loadHtmlString(_buildInteractiveHtml(code));
      setState(() {
        diagram = data;
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Eliminar diagrama',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          '¿Seguro que quieres eliminar "${diagram?['name'] ?? ''}"? Esta acción no se puede deshacer.',
          style: const TextStyle(color: fsdTextGrey, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: fsdTextGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: fsdPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteDiagram(widget.diagramId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Diagrama eliminado'),
          backgroundColor: fsdPink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: fsdPink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  Future<void> _showRenameDialog() async {
    final d = diagram;
    if (d == null) return;

    final controller = TextEditingController(text: d['name']?.toString() ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF151823);
    final border = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);

    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Renombrar diagrama',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark
                ? const Color(0xFF252838)
                : const Color(0xFFF6F7FB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: fsdPink),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: fsdTextGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: fsdPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmed == null || confirmed.isEmpty) return;

    try {
      final updated = await ApiService.patchDiagram(
        widget.diagramId,
        {'name': confirmed},
      );
      if (!mounted) return;
      setState(() => diagram = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Error: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: fsdPink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  String _typeLabel(String type) {
    return _diagramTypeMap[type] ?? type.toUpperCase().replaceAll('_', ' ');
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'Borrador';
      case 'published':
        return 'Publicado';
      case 'archived':
        return 'Archivado';
      default:
        return status.isEmpty ? 'Borrador' : status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return const Color(0xFF1BC47D);
      case 'archived':
        return const Color(0xFF8E8E93);
      default:
        return const Color(0xFF55A6FF);
    }
  }

  Color _statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return const Color(0x221BC47D);
      case 'archived':
        return const Color(0x228E8E93);
      default:
        return const Color(0x2255A6FF);
    }
  }

  void _openFocusMode() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FocusModeEditor(
        initialCode: _codeController.text,
        onDone: (code) async {
          _codeController.text = code;
          if (code != _initialCode) {
            await _save();
          }
        },
      ),
    );
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return 'Sin fecha';
    try {
      final d = DateTime.parse(raw).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    } catch (_) {
      return raw;
    }
  }

  String _projectName(dynamic d) {
    final p = d?['project'];
    if (p == null) return '—';
    if (p is Map) return (p['name'] ?? p['code'] ?? '—').toString();
    return p.toString();
  }

  String _extractEmail(dynamic creator) {
    if (creator == null) return '—';
    if (creator is Map) {
      return (creator['email'] ?? creator['username'] ?? '—').toString();
    }
    return creator.toString();
  }

  @override
  Widget build(BuildContext context) {
    final d = diagram;
    final name = d == null ? 'Diagrama' : (d['name'] ?? 'Diagrama').toString();

    return Scaffold(
      backgroundColor: const Color(0xFF0F1017),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: fsdPink))
            : errorMessage != null
                ? _ErrorState(
                    message: errorMessage!,
                    onRetry: () {
                      setState(() => loading = true);
                      _load();
                    },
                  )
                : Column(
                    children: [
                      // ── Top bar ─────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: fsdBorderColor),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            // Guardar — siempre visible
                            if (_isSaving)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: fsdPink, strokeWidth: 2.2),
                              )
                            else
                              FilledButton(
                                onPressed: _isDirty ? _saveManual : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: fsdPink,
                                  disabledBackgroundColor:
                                      const Color(0xFF2C2C3E),
                                  foregroundColor: Colors.white,
                                  disabledForegroundColor: fsdTextGrey,
                                  minimumSize: const Size(0, 32),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                child: const Text('Guardar',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                      ),
                      // ── Secondary bar: tabs + actions ───────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: fsdBorderColor),
                          ),
                        ),
                        child: Row(
                          children: [
                            _EditorTab(
                              label: 'VISUAL',
                              active: _viewMode == _ViewMode.visual,
                              onTap: () =>
                                  setState(() => _viewMode = _ViewMode.visual),
                            ),
                            const SizedBox(width: 4),
                            _EditorTab(
                              label: 'CÓDIGO',
                              active: _viewMode == _ViewMode.code,
                              onTap: () =>
                                  setState(() => _viewMode = _ViewMode.code),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Renombrar',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _showRenameDialog,
                              icon: const Icon(
                                Icons.drive_file_rename_outline_rounded,
                                color: fsdTextGrey,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              tooltip: 'Eliminar',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _confirmDelete,
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: fsdPink,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── Canvas ──────────────────────────────────────────
                      Expanded(
                        child: _viewMode == _ViewMode.visual
                            ? _isInteractiveType
                                ? Stack(
                                    children: [
                                      WebViewWidget(
                                          controller: _interactiveController),
                                      if (_interactiveLoading)
                                        const Center(
                                          child: CircularProgressIndicator(
                                              color: fsdPink,
                                              strokeWidth: 2.5),
                                        ),
                                      // Panel de herramientas desplegable
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: _InteractiveToolPanel(
                                          isOpen: _bottomPanelOpen,
                                          diagramType: _diagramType,
                                          onToggle: () => setState(() =>
                                              _bottomPanelOpen =
                                                  !_bottomPanelOpen),
                                          edgeModeActive: _edgeModeActive,
                                          onJsCall: _jsCall,
                                          onToggleEdge: _toggleEdgeMode,
                                        ),
                                      ),
                                    ],
                                  )
                                : Stack(
                                    children: [
                                      WebViewWidget(
                                          controller: _webViewController),
                                      if (_previewLoading)
                                        const Center(
                                          child: CircularProgressIndicator(
                                              color: fsdPink,
                                              strokeWidth: 2.5),
                                        ),
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: _RefreshButton(
                                            onRefresh: _refreshPreview),
                                      ),
                                    ],
                                  )
                            : _CodePanel(
                                controller: _codeController,
                                onRefreshPreview: _refreshPreview,
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

// ─── Mermaid code editor ─────────────────────────────────────────────────────

class _MermaidCodeEditor extends StatelessWidget {
  final TextEditingController controller;
  final bool isDirty;
  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onRefreshPreview;
  final VoidCallback onFocusMode;

  const _MermaidCodeEditor({
    required this.controller,
    required this.isDirty,
    required this.isSaving,
    required this.onSave,
    required this.onRefreshPreview,
    required this.onFocusMode,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? fsdCardBg : Colors.white;
    final border = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);
    final codeBg = isDark ? const Color(0xFF0F1017) : const Color(0xFFF0F2F8);
    final titleColor = isDark ? Colors.white : const Color(0xFF151823);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.code_rounded, size: 16, color: fsdTextGrey),
                const SizedBox(width: 8),
                Text(
                  'Código Mermaid',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                // Modo enfoque
                IconButton(
                  tooltip: 'Modo enfoque',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: onFocusMode,
                  icon: const Icon(Icons.open_in_full_rounded, size: 17, color: fsdTextGrey),
                ),
                const SizedBox(width: 2),
                if (isSaving)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: fsdPink,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else if (isDirty)
                  TextButton.icon(
                    onPressed: onSave,
                    style: TextButton.styleFrom(
                      foregroundColor: fsdPink,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.save_outlined, size: 15),
                    label: const Text(
                      'Guardar',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Guardado',
                      style: TextStyle(
                        color: const Color(0xFF1BC47D).withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: codeBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: TextField(
              controller: controller,
              maxLines: 10,
              minLines: 6,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFFCDD3DE),
                height: 1.6,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
                hintText: 'graph TD\n  A --> B',
                hintStyle: TextStyle(
                  color: fsdTextGrey,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRefreshPreview,
                icon: const Icon(Icons.preview_rounded, size: 16),
                label: const Text('Actualizar vista previa'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: fsdPink,
                  side: const BorderSide(color: fsdPink),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── View mode tab switcher ───────────────────────────────────────────────────

class _ViewModeSwitcher extends StatelessWidget {
  final _ViewMode mode;
  final ValueChanged<_ViewMode> onChanged;

  const _ViewModeSwitcher({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? fsdCardBg : Colors.white;
    final border = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Visual',
            icon: Icons.drag_indicator_rounded,
            selected: mode == _ViewMode.visual,
            onTap: () => onChanged(_ViewMode.visual),
          ),
          _Tab(
            label: 'Código',
            icon: Icons.code_rounded,
            selected: mode == _ViewMode.code,
            onTap: () => onChanged(_ViewMode.code),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? const Color(0xFF3A1A22) : const Color(0xFFFFECF0))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? fsdPink : fsdTextGrey,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? fsdPink : fsdTextGrey,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Interactive cytoscape editor ─────────────────────────────────────────────

class _InteractiveEditor extends StatelessWidget {
  final WebViewController webViewController;
  final bool isLoading;

  const _InteractiveEditor({
    required this.webViewController,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1017) : const Color(0xFFF0F2F8);
    final border = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);

    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          WebViewWidget(controller: webViewController),
          if (isLoading)
            Container(
              color: bg,
              child: const Center(
                child: CircularProgressIndicator(color: fsdPink, strokeWidth: 2.5),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Mermaid Preview (WebView) ────────────────────────────────────────────────

class _MermaidPreview extends StatelessWidget {
  final WebViewController webViewController;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _MermaidPreview({
    required this.webViewController,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1017) : const Color(0xFFF0F2F8);
    final border = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          WebViewWidget(controller: webViewController),
          if (isLoading)
            Container(
              color: bg,
              child: const Center(
                child: CircularProgressIndicator(color: fsdPink, strokeWidth: 2.5),
              ),
            ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onRefresh,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xCCE8365D),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Actualizar',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Focus mode editor (fullscreen bottom sheet) ──────────────────────────────

class _FocusModeEditor extends StatefulWidget {
  final String initialCode;
  final Future<void> Function(String code) onDone;

  const _FocusModeEditor({required this.initialCode, required this.onDone});

  @override
  State<_FocusModeEditor> createState() => _FocusModeEditorState();
}

class _FocusModeEditorState extends State<_FocusModeEditor> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialCode);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onDone(_ctrl.text);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? fsdDarkBg : Colors.white;
    final codeBg = isDark ? const Color(0xFF0F1017) : const Color(0xFFF0F2F8);
    final border = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);

    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: fsdTextGrey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
            child: Row(
              children: [
                const Icon(Icons.code_rounded, color: fsdPink, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Modo enfoque',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF151823),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: fsdTextGrey)),
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: fsdPink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Code editor
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: codeBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: TextField(
                  controller: _ctrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: Color(0xFFCDD3DE),
                    height: 1.7,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                    hintText: 'graph TD\n  A --> B',
                    hintStyle: TextStyle(color: fsdTextGrey, fontFamily: 'monospace', fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info section ────────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final Map<String, dynamic> diagram;
  final String typeLabel;
  final String statusLabel;
  final Color statusColor;
  final Color statusBg;
  final String projectName;
  final String creatorEmail;
  final String createdAt;
  final String updatedAt;

  const _InfoSection({
    required this.diagram,
    required this.typeLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.statusBg,
    required this.projectName,
    required this.creatorEmail,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? fsdCardBg : Colors.white;
    final border = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);
    final titleColor = isDark ? Colors.white : const Color(0xFF151823);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Información',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: 'Tipo',
            value: typeLabel,
            isDark: isDark,
          ),
          _InfoRow(
            label: 'Proyecto',
            value: projectName,
            isDark: isDark,
          ),
          _InfoRow(
            label: 'Creado por',
            value: creatorEmail,
            isDark: isDark,
          ),
          _InfoRow(
            label: 'Creado',
            value: createdAt,
            isDark: isDark,
          ),
          _InfoRow(
            label: 'Actualizado',
            value: updatedAt,
            isDark: isDark,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final bool last;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : const Color(0xFF151823);
    final border = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: fsdTextGrey,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!last) Divider(color: border, height: 1),
      ],
    );
  }
}

// ─── Diagram top-bar tab selector ────────────────────────────────────────────

class _DiagramTabBar extends StatelessWidget {
  final _DiagramViewMode current;
  final ValueChanged<_DiagramViewMode> onChanged;

  const _DiagramTabBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? fsdCardBg : Colors.white;
    final border = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DTab(
            label: 'FORMULARIO',
            value: _DiagramViewMode.formulario,
            current: current,
            onTap: () => onChanged(_DiagramViewMode.formulario),
          ),
          _DTab(
            label: 'JSON',
            value: _DiagramViewMode.json,
            current: current,
            onTap: () => onChanged(_DiagramViewMode.json),
          ),
          _DTab(
            label: '✦ IA',
            value: _DiagramViewMode.ai,
            current: current,
            onTap: () => onChanged(_DiagramViewMode.ai),
          ),
        ],
      ),
    );
  }
}

class _DTab extends StatelessWidget {
  final String label;
  final _DiagramViewMode value;
  final _DiagramViewMode current;
  final VoidCallback onTap;

  const _DTab({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? const Color(0xFF3A1A22) : const Color(0xFFFFECF0))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? fsdPink : fsdTextGrey,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}


// ─── AI placeholder ───────────────────────────────────────────────────────────

class _AiPlaceholder extends StatelessWidget {
  const _AiPlaceholder();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? fsdCardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? fsdBorderColor : const Color(0xFFE5E7EF),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 40, color: fsdPink),
          const SizedBox(height: 16),
          const Text(
            '✦ Asistente IA',
            style: TextStyle(
              color: fsdPink,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generación y edición de diagramas con inteligencia artificial.\nPróximamente disponible.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fsdTextGrey,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error state ─────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: fsdPink),
            const SizedBox(height: 14),
            const Text(
              'Error al cargar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(color: fsdTextGrey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: fsdPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Interactive bottom tool panel ───────────────────────────────────────────

class _InteractiveToolPanel extends StatelessWidget {
  final bool isOpen;
  final String diagramType;
  final VoidCallback onToggle;
  final bool edgeModeActive;
  final void Function(String) onJsCall;
  final VoidCallback onToggleEdge;

  const _InteractiveToolPanel({
    required this.isOpen,
    required this.diagramType,
    required this.onToggle,
    required this.edgeModeActive,
    required this.onJsCall,
    required this.onToggleEdge,
  });

  List<_ToolItem> get _items {
    final canvasItems = <_ToolItem>[
      _ToolItem(label: edgeModeActive ? 'Cancelar' : 'Conectar', icon: Icons.linear_scale_rounded, color: const Color(0xFF55A6FF), onTap: onToggleEdge, active: edgeModeActive),
      _ToolItem(label: 'Eliminar', icon: Icons.delete_outline_rounded, color: fsdPink, onTap: () => onJsCall('deleteSelected()')),
      _ToolItem(label: 'Layout', icon: Icons.auto_fix_high_rounded, color: const Color(0xFF1BC47D), onTap: () => onJsCall('layoutAuto()')),
      _ToolItem(label: 'Ajustar', icon: Icons.fit_screen_rounded, color: const Color(0xFF55A6FF), onTap: () => onJsCall('fitView()')),
    ];

    switch (diagramType) {
      case 'flowchart':
        return [
          _ToolItem(label: 'Inicio', icon: Icons.play_circle_outline_rounded, color: fsdPink, onTap: () => onJsCall("addNodeOfType('ellipse','start','Inicio')")),
          _ToolItem(label: 'Fin', icon: Icons.stop_circle_outlined, color: const Color(0xFF1BC47D), onTap: () => onJsCall("addNodeOfType('ellipse','end','Fin')")),
          _ToolItem(label: 'Proceso', icon: Icons.crop_square_rounded, color: const Color(0xFF55A6FF), onTap: () => onJsCall("addNodeOfType('roundrectangle',null,'Proceso')")),
          _ToolItem(label: 'Decisión', icon: Icons.diamond_outlined, color: const Color(0xFFF2A91D), onTap: () => onJsCall("addNodeOfType('diamond','decision','¿Condición?')")),
          _ToolItem(label: 'Nota', icon: Icons.sticky_note_2_outlined, color: const Color(0xFFF2A91D), onTap: () => onJsCall("addNodeOfType('rectangle','note','Nota')")),
          _ToolItem(label: 'Flecha', icon: Icons.arrow_forward_rounded, color: const Color(0xFF8E8E93), onTap: () => onJsCall('addEdgeOfType(null)')),
          _ToolItem(label: 'Punteada', icon: Icons.more_horiz_rounded, color: const Color(0xFF8E8E93), onTap: () => onJsCall("addEdgeOfType('dashed')")),
          _ToolItem(label: 'Sin flecha', icon: Icons.horizontal_rule_rounded, color: const Color(0xFF3A3A3C), onTap: () => onJsCall("addEdgeOfType('assoc-line')")),
          ...canvasItems,
        ];
      case 'activity':
        return [
          _ToolItem(label: 'Inicio', icon: Icons.play_circle_outline_rounded, color: fsdPink, onTap: () => onJsCall("addNodeOfType('ellipse','start','Inicio')")),
          _ToolItem(label: 'Fin', icon: Icons.stop_circle_outlined, color: const Color(0xFF1BC47D), onTap: () => onJsCall("addNodeOfType('ellipse','end','Fin')")),
          _ToolItem(label: 'Acción', icon: Icons.crop_square_rounded, color: const Color(0xFF55A6FF), onTap: () => onJsCall("addNodeOfType('roundrectangle',null,'Acción')")),
          _ToolItem(label: 'Decisión', icon: Icons.diamond_outlined, color: const Color(0xFFF2A91D), onTap: () => onJsCall("addNodeOfType('diamond','decision','¿Condición?')")),
          _ToolItem(label: 'Fork/Join', icon: Icons.compare_arrows_rounded, color: const Color(0xFFCDD3DE), onTap: () => onJsCall("addNodeOfType('rectangle','fork-join','Fork')")),
          _ToolItem(label: 'Nota', icon: Icons.sticky_note_2_outlined, color: const Color(0xFFF2A91D), onTap: () => onJsCall("addNodeOfType('rectangle','note','Nota')")),
          _ToolItem(label: 'Transición', icon: Icons.arrow_forward_rounded, color: const Color(0xFF8E8E93), onTap: () => onJsCall('addEdgeOfType(null)')),
          _ToolItem(label: 'Punteada', icon: Icons.more_horiz_rounded, color: const Color(0xFF8E8E93), onTap: () => onJsCall("addEdgeOfType('dashed')")),
          ...canvasItems,
        ];
      case 'use-case':
        return [
          _ToolItem(label: 'Actor', icon: Icons.person_outline_rounded, color: const Color(0xFFFF9800), onTap: () => onJsCall("addNodeOfType('ellipse','actor','Actor')")),
          _ToolItem(label: 'Caso de Uso', icon: Icons.radio_button_unchecked_rounded, color: const Color(0xFF55A6FF), onTap: () => onJsCall("addNodeOfType('ellipse','usecase','Caso de Uso')")),
          _ToolItem(label: 'Sistema', icon: Icons.crop_square_rounded, color: const Color(0xFFCDD3DE), onTap: () => onJsCall("addNodeOfType('rectangle','boundary','Sistema')")),
          _ToolItem(label: 'Nota', icon: Icons.sticky_note_2_outlined, color: const Color(0xFFF2A91D), onTap: () => onJsCall("addNodeOfType('rectangle','note','Nota')")),
          _ToolItem(label: 'Asociación', icon: Icons.arrow_forward_rounded, color: const Color(0xFF8E8E93), onTap: () => onJsCall('addEdgeOfType(null)')),
          _ToolItem(label: 'Include', icon: Icons.subdirectory_arrow_right_rounded, color: const Color(0xFF55A6FF), onTap: () => onJsCall("addEdgeLabeled('include-rel','<<include>>')")),
          _ToolItem(label: 'Extend', icon: Icons.call_split_rounded, color: const Color(0xFFF2A91D), onTap: () => onJsCall("addEdgeLabeled('extend-rel','<<extend>>')")),
          _ToolItem(label: 'Sin flecha', icon: Icons.horizontal_rule_rounded, color: const Color(0xFF3A3A3C), onTap: () => onJsCall("addEdgeOfType('assoc-line')")),
          ...canvasItems,
        ];
      case 'class':
        return [
          _ToolItem(label: 'Clase', icon: Icons.crop_square_rounded, color: const Color(0xFF55A6FF), onTap: () => onJsCall("addNodeOfType('roundrectangle',null,'Clase')")),
          _ToolItem(label: 'Interfaz', icon: Icons.layers_outlined, color: const Color(0xFF9B59B6), onTap: () => onJsCall("addNodeOfType('rectangle','interface-cls','<<interface>>')")),
          _ToolItem(label: 'Abstracta', icon: Icons.rectangle_outlined, color: fsdPink, onTap: () => onJsCall("addNodeOfType('roundrectangle','abstract-cls','<<abstract>>')")),
          _ToolItem(label: 'Nota', icon: Icons.sticky_note_2_outlined, color: const Color(0xFFF2A91D), onTap: () => onJsCall("addNodeOfType('rectangle','note','Nota')")),
          _ToolItem(label: 'Herencia', icon: Icons.call_merge_rounded, color: const Color(0xFFCDD3DE), onTap: () => onJsCall("addEdgeOfType('inheritance')")),
          _ToolItem(label: 'Composición', icon: Icons.diamond_rounded, color: const Color(0xFF55A6FF), onTap: () => onJsCall("addEdgeOfType('composition')")),
          _ToolItem(label: 'Agregación', icon: Icons.diamond_outlined, color: const Color(0xFF55A6FF), onTap: () => onJsCall("addEdgeOfType('aggregation')")),
          _ToolItem(label: 'Dependencia', icon: Icons.more_horiz_rounded, color: const Color(0xFF8E8E93), onTap: () => onJsCall("addEdgeOfType('dependency')")),
          _ToolItem(label: 'Asociación', icon: Icons.arrow_forward_rounded, color: const Color(0xFF8E8E93), onTap: () => onJsCall('addEdgeOfType(null)')),
          ...canvasItems,
        ];
      case 'sequence':
        return [
          _ToolItem(label: 'Actor', icon: Icons.person_outline_rounded, color: const Color(0xFFFF9800), onTap: () => onJsCall("addNodeOfType('ellipse','seq-actor','Actor')")),
          _ToolItem(label: 'Objeto', icon: Icons.rectangle_outlined, color: const Color(0xFF55A6FF), onTap: () => onJsCall("addNodeOfType('rectangle','seq-obj','Objeto')")),
          _ToolItem(label: 'Fragmento', icon: Icons.flip_to_front_outlined, color: const Color(0xFF1BC47D), onTap: () => onJsCall("addNodeOfType('rectangle','fragment','Fragment')")),
          _ToolItem(label: 'Nota', icon: Icons.sticky_note_2_outlined, color: const Color(0xFFF2A91D), onTap: () => onJsCall("addNodeOfType('rectangle','note','Nota')")),
          _ToolItem(label: 'Mensaje', icon: Icons.arrow_forward_rounded, color: const Color(0xFF8E8E93), onTap: () => onJsCall('addEdgeOfType(null)')),
          _ToolItem(label: 'Retorno', icon: Icons.keyboard_return_rounded, color: const Color(0xFF55A6FF), onTap: () => onJsCall("addEdgeOfType('dashed')")),
          _ToolItem(label: 'Asíncrono', icon: Icons.double_arrow_rounded, color: const Color(0xFFCDD3DE), onTap: () => onJsCall("addEdgeOfType('dotted')")),
          _ToolItem(label: 'Auto-msg', icon: Icons.refresh_rounded, color: const Color(0xFFF2A91D), onTap: () => onJsCall('addSelfEdge()')),
          ...canvasItems,
        ];
      case 'er':
        return [
          _ToolItem(label: 'Entidad', icon: Icons.crop_square_rounded, color: const Color(0xFF55A6FF), onTap: () => onJsCall("addNodeOfType('rectangle',null,'Entidad')")),
          _ToolItem(label: 'Atributo', icon: Icons.radio_button_unchecked_rounded, color: const Color(0xFF1BC47D), onTap: () => onJsCall("addNodeOfType('ellipse','er-attr','atributo')")),
          _ToolItem(label: 'Relación', icon: Icons.diamond_outlined, color: const Color(0xFFF2A91D), onTap: () => onJsCall("addNodeOfType('diamond','decision','relación')")),
          _ToolItem(label: 'E. Débil', icon: Icons.crop_din_rounded, color: const Color(0xFFF2A91D), onTap: () => onJsCall("addNodeOfType('rectangle','er-weak','E. Débil')")),
          _ToolItem(label: 'Línea', icon: Icons.horizontal_rule_rounded, color: const Color(0xFF8E8E93), onTap: () => onJsCall("addEdgeOfType('assoc-line')")),
          _ToolItem(label: '1:1', icon: Icons.looks_one_outlined, color: const Color(0xFF1BC47D), onTap: () => onJsCall("addEdgeLabeled('one-to-one','1:1')")),
          _ToolItem(label: '1:N', icon: Icons.looks_two_outlined, color: const Color(0xFF55A6FF), onTap: () => onJsCall("addEdgeLabeled('one-to-many','1:N')")),
          _ToolItem(label: 'N:M', icon: Icons.all_inclusive_rounded, color: const Color(0xFFF2A91D), onTap: () => onJsCall("addEdgeLabeled('many-to-many','N:M')")),
          ...canvasItems,
        ];
      case 'state':
        return [
          _ToolItem(label: 'Inicial', icon: Icons.play_circle_filled_rounded, color: fsdPink, onTap: () => onJsCall("addNodeOfType('ellipse','start','●')")),
          _ToolItem(label: 'Estado', icon: Icons.crop_square_rounded, color: const Color(0xFF55A6FF), onTap: () => onJsCall("addNodeOfType('roundrectangle',null,'Estado')")),
          _ToolItem(label: 'Final', icon: Icons.stop_circle_rounded, color: const Color(0xFF1BC47D), onTap: () => onJsCall("addNodeOfType('ellipse','end','◉')")),
          _ToolItem(label: 'Compuesto', icon: Icons.view_quilt_outlined, color: const Color(0xFF55A6FF), onTap: () => onJsCall("addNodeOfType('roundrectangle','composite','Compuesto')")),
          _ToolItem(label: 'Nota', icon: Icons.sticky_note_2_outlined, color: const Color(0xFFF2A91D), onTap: () => onJsCall("addNodeOfType('rectangle','note','Nota')")),
          _ToolItem(label: 'Transición', icon: Icons.arrow_forward_rounded, color: const Color(0xFF8E8E93), onTap: () => onJsCall('addEdgeOfType(null)')),
          _ToolItem(label: 'Interna', icon: Icons.more_horiz_rounded, color: const Color(0xFF8E8E93), onTap: () => onJsCall("addEdgeOfType('dashed')")),
          _ToolItem(label: 'Auto-trans.', icon: Icons.refresh_rounded, color: const Color(0xFFF2A91D), onTap: () => onJsCall('addSelfEdge()')),
          ...canvasItems,
        ];
      case 'mr':
        return [
          _ToolItem(label: 'Tabla', icon: Icons.table_chart_outlined, color: const Color(0xFF55A6FF), onTap: () => onJsCall("addNodeOfType('rectangle','table-node','Tabla')")),
          _ToolItem(label: 'PK', icon: Icons.vpn_key_outlined, color: fsdPink, onTap: () => onJsCall("addNodeOfType('roundrectangle','pk-field','PK: id')")),
          _ToolItem(label: 'FK', icon: Icons.link_rounded, color: const Color(0xFF55A6FF), onTap: () => onJsCall("addNodeOfType('roundrectangle','fk-field','FK: id')")),
          _ToolItem(label: 'Campo', icon: Icons.text_fields_rounded, color: const Color(0xFFCDD3DE), onTap: () => onJsCall("addNodeOfType('roundrectangle',null,'campo')")),
          _ToolItem(label: '1:1', icon: Icons.looks_one_outlined, color: const Color(0xFF1BC47D), onTap: () => onJsCall("addEdgeLabeled('one-to-one','1:1')")),
          _ToolItem(label: '1:N', icon: Icons.looks_two_outlined, color: const Color(0xFF55A6FF), onTap: () => onJsCall("addEdgeLabeled('one-to-many','1:N')")),
          _ToolItem(label: 'N:M', icon: Icons.all_inclusive_rounded, color: const Color(0xFFF2A91D), onTap: () => onJsCall("addEdgeLabeled('many-to-many','N:M')")),
          _ToolItem(label: 'Relación', icon: Icons.arrow_forward_rounded, color: const Color(0xFF8E8E93), onTap: () => onJsCall('addEdgeOfType(null)')),
          ...canvasItems,
        ];
      default:
        return [
          _ToolItem(label: 'Nodo', icon: Icons.crop_square_rounded, color: const Color(0xFF55A6FF), onTap: () => onJsCall("addNodeOfType('roundrectangle',null,'Nodo')")),
          _ToolItem(label: 'Inicio', icon: Icons.play_circle_outline_rounded, color: fsdPink, onTap: () => onJsCall("addNodeOfType('ellipse','start','Inicio')")),
          _ToolItem(label: 'Fin', icon: Icons.stop_circle_outlined, color: const Color(0xFF1BC47D), onTap: () => onJsCall("addNodeOfType('ellipse','end','Fin')")),
          _ToolItem(label: 'Decisión', icon: Icons.diamond_outlined, color: const Color(0xFFF2A91D), onTap: () => onJsCall("addNodeOfType('diamond','decision','¿Condición?')")),
          _ToolItem(label: 'Flecha', icon: Icons.arrow_forward_rounded, color: const Color(0xFF8E8E93), onTap: () => onJsCall('addEdgeOfType(null)')),
          _ToolItem(label: 'Punteada', icon: Icons.more_horiz_rounded, color: const Color(0xFF8E8E93), onTap: () => onJsCall("addEdgeOfType('dashed')")),
          ...canvasItems,
        ];
    }
  }

  static const double _panelHeight = 164.0;

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Botón toggle centrado ──
        Center(
          child: GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C2E),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border.all(color: fsdBorderColor),
                boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, -3))],
              ),
              child: AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
        // ── Grid de componentes ──
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          height: isOpen ? _panelHeight : 0,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C2E),
            border: Border(top: BorderSide(color: fsdBorderColor)),
          ),
          child: GridView.count(
            crossAxisCount: 4,
            childAspectRatio: 1.15,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            physics: const BouncingScrollPhysics(),
            children: items.map((item) => _ToolTile(item: item)).toList(),
          ),
        ),
      ],
    );
  }
}

class _ToolItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool active;
  const _ToolItem({required this.label, required this.icon, required this.color, required this.onTap, this.active = false});
}

class _ToolTile extends StatelessWidget {
  final _ToolItem item;
  const _ToolTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: item.active ? fsdPink.withOpacity(0.15) : const Color(0xFF252838),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: item.active ? fsdPink : fsdBorderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 20, color: item.active ? fsdPink : item.color),
            const SizedBox(height: 4),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: TextStyle(color: item.active ? fsdPink : fsdTextGrey, fontSize: 10, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool danger;

  const _ToolBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? fsdPink
        : active
            ? const Color(0xFF55A6FF)
            : fsdTextGrey;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Editor tab chip ─────────────────────────────────────────────────────────

class _EditorTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _EditorTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? fsdPink : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : fsdTextGrey,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

// ─── Refresh button overlay ──────────────────────────────────────────────────

class _RefreshButton extends StatelessWidget {
  final VoidCallback onRefresh;
  const _RefreshButton({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRefresh,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fsdBorderColor),
        ),
        child: const Icon(Icons.refresh_rounded,
            color: fsdTextGrey, size: 18),
      ),
    );
  }
}

// ─── Code panel (full-screen code editor) ────────────────────────────────────

class _CodePanel extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onRefreshPreview;

  const _CodePanel({
    required this.controller,
    required this.onRefreshPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: const Color(0xFF0F1017),
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.6,
              ),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.all(16),
                border: InputBorder.none,
                hintText: 'Escribe el código Mermaid...',
                hintStyle: TextStyle(color: fsdTextGrey),
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: fsdBorderColor)),
          ),
          child: FilledButton.icon(
            onPressed: onRefreshPreview,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2C2C3E),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Actualizar vista previa'),
          ),
        ),
      ],
    );
  }
}
