import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Diagram Editor Screen
// Full-screen focus-mode editor: top app bar + cytoscape canvas + component panel
// ─────────────────────────────────────────────────────────────────────────────

class DiagramEditorScreen extends StatefulWidget {
  final int diagramId;
  final String? initialCode;
  final String? diagramName;
  final String? diagramType;

  const DiagramEditorScreen({
    super.key,
    required this.diagramId,
    this.initialCode,
    this.diagramName,
    this.diagramType,
  });

  @override
  State<DiagramEditorScreen> createState() => _DiagramEditorScreenState();
}

class _DiagramEditorScreenState extends State<DiagramEditorScreen> {
  late String _code;
  bool _saving = false;
  bool _dirty = false;
  bool _canvasLoading = true;
  bool _panelOpen = false;
  bool _isDark = true;
  bool _htmlLoaded = false;

  late final WebViewController _controller;
  Timer? _autosaveTimer;

  // Diagram type used to decide which component palette to show
  String get _type =>
      (widget.diagramType ?? '').toLowerCase().replaceAll('_', '-');


  @override
  void initState() {
    super.initState();
    _code = widget.initialCode ?? '';
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('FlutterBridge',
          onMessageReceived: _onCodeFromJs)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _canvasLoading = false);
        },
      ));
    // HTML loads in didChangeDependencies (needs theme)
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!_htmlLoaded || isDark != _isDark) {
      _isDark = isDark;
      _htmlLoaded = true;
      if (_htmlLoaded) setState(() => _canvasLoading = true);
      _controller.loadHtmlString(_buildHtml(_code, isDark));
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── JS → Flutter bridge ──
  void _onCodeFromJs(JavaScriptMessage msg) {
    final m = msg.message;
    if (m.startsWith('__rename:')) {
      final parts = m.substring(9).split(':');
      final nodeId = parts[0];
      final currentLabel = parts.length > 1 ? parts.sublist(1).join(':') : '';
      _showRenameDialog(nodeId, currentLabel);
      return;
    }
    if (m.startsWith('__edgeMode:')) return;
    if (m == _code) return;
    _code = m;
    _dirty = true;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 4), _autosave);
    if (mounted) setState(() {});
  }

  Future<void> _showRenameDialog(String nodeId, String currentLabel) async {
    final controller = TextEditingController(text: currentLabel);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Renombrar nodo',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: cs.onSurface),
          cursorColor: fsdPink,
          decoration: InputDecoration(
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            hintText: 'Nombre del nodo',
            hintStyle: const TextStyle(color: fsdTextGrey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.outlineVariant),
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
      );
      },
    );
    if (!mounted) return;
    if (newLabel != null && newLabel.isNotEmpty) {
      final safe = newLabel.replaceAll("'", "\\'");
      _jsCall("renameNode('$nodeId','$safe')");
    }
  }

  Future<void> _autosave() async {
    if (!_dirty) return;
    try {
      await ApiService.patchDiagram(widget.diagramId, {'mermaid_code': _code});
      if (!mounted) return;
      setState(() => _dirty = false);
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ApiService.patchDiagram(widget.diagramId, {'mermaid_code': _code});
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Guardado'),
        backgroundColor: fsdPink,
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e'.replaceFirst('Exception: ', '')),
        backgroundColor: fsdPink,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── JS call helpers ──
  void _jsCall(String fn) => _controller.runJavaScript(fn);

  // ────────────────────────────────────────────────────────────────────────
  // HTML / cytoscape
  // ────────────────────────────────────────────────────────────────────────
  String _buildHtml(String code, bool isDark) {
    final escaped = code
        .replaceAll(r'\', r'\\')
        .replaceAll('`', r'\`')
        .replaceAll(r'$', r'\$');

    final bg        = isDark ? '#0F1017' : '#F6F7FB';
    final nodeBg    = isDark ? '#2C2C3E' : '#FFFFFF';
    final neutral   = isDark ? '#3A3A3C' : '#C8CBD4';
    final lightText = isDark ? '#CDD3DE' : '#1A1E2B';
    final deepBg    = isDark ? '#1E2130' : '#EEF0F5';
    final altBg     = isDark ? '#1A1A2E' : '#EEF0F5';

    const head = r'''<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:100%;height:100%;background:__BG__;overflow:hidden}
#cy{width:100vw;height:100vh}
</style>
</head>
<body>
<div id="cy"></div>
<script src="https://cdn.jsdelivr.net/npm/cytoscape@3.28.1/dist/cytoscape.min.js"></script>
<script>
var edgeMode=false,edgeSource=null,nodeCounter=0,viewOnly=false;
function parseMermaid(code){
  var nodes={},edges=[];
  var lines=code.split('\n').filter(function(l){
    return !l.trim().match(/^(graph|flowchart|stateDiagram|sequenceDiagram|classDiagram|erDiagram)/i);
  });
  function cleanId(s){s=s.trim().replace(/^["']|["']$/g,'');var m=s.match(/^(\w+)[\[\(\{>]/);return m?m[1]:s.trim()||s;}
  function cleanLabel(s){s=s.trim();var m=s.match(/^\w+[\[\(\{>]([^\]\)\}]*)[\]\)\}]$/);if(m)return m[1];m=s.match(/^["'](.*)["']$/);if(m)return m[1];return cleanId(s);}
  function ensureNode(raw){var id=cleanId(raw);if(!nodes[id])nodes[id]=cleanLabel(raw);return id;}
  lines.forEach(function(line){
    line=line.trim();
    if(!line||line.indexOf('%%')===0)return;
    var arrowIdx=line.indexOf('-->');
    if(arrowIdx===-1)arrowIdx=line.indexOf('->');
    if(arrowIdx!==-1){
      var lm=line.match(/-->\|([^|]*)\|/);var eLabel=lm?lm[1]:'';
      var rest=line,parts=[],chunk='',i=0;
      while(i<rest.length){
        if(rest.substr(i,3)==='-->'){parts.push(chunk.trim());chunk='';i+=3;if(rest[i]==='|'){var e=rest.indexOf('|',i+1);if(e!==-1){eLabel=rest.substring(i+1,e);i=e+1;}}}
        else if(rest.substr(i,2)==='->'){parts.push(chunk.trim());chunk='';i+=2;}
        else{chunk+=rest[i];i++;}
      }
      parts.push(chunk.trim());
      if(parts.length>=2){var src=ensureNode(parts[0]);for(var j=1;j<parts.length;j++){if(!parts[j])continue;var tgt=ensureNode(parts[j]);edges.push({source:src,target:tgt,label:eLabel});src=tgt;eLabel='';}}
    }else{ensureNode(line);}
    nodeCounter=Math.max(nodeCounter,Object.keys(nodes).length);
  });
  return{nodes:nodes,edges:edges};
}
var initialCode=`''';

    const tail = r'''`;
var parsed=parseMermaid(initialCode);
var cyEls=[];
Object.keys(parsed.nodes).forEach(function(id){cyEls.push({data:{id:id,label:parsed.nodes[id]||id}});});
parsed.edges.forEach(function(e,i){cyEls.push({data:{id:'e'+i,source:e.source,target:e.target,label:e.label}});});
var cy=cytoscape({
  container:document.getElementById('cy'),
  elements:cyEls,
  style:[
    {selector:'node',style:{
      'background-color':'#2C2C3E','border-width':2,'border-color':'#3A3A3C',
      'color':'#CDD3DE','label':'data(label)','font-size':'13px',
      'text-valign':'center','text-halign':'center',
      'width':'label','height':'label','padding':'12px',
      'shape':'roundrectangle','text-wrap':'wrap','text-max-width':'130px'}},
    {selector:'node.decision',style:{'shape':'diamond','padding':'16px'}},
    {selector:'node.start',style:{'shape':'ellipse','background-color':'#E8365D','border-color':'#E8365D','color':'#fff'}},
    {selector:'node.end',style:{'shape':'ellipse','background-color':'#1BC47D','border-color':'#1BC47D','color':'#fff'}},
    {selector:'node.note',style:{'shape':'rectangle','background-color':'#F2A91D22','border-color':'#F2A91D','color':'#F2A91D'}},
    {selector:'node:selected',style:{'border-color':'#E8365D','border-width':2.5,'background-color':'#E8365D22'}},
    {selector:'node.edge-source',style:{'border-color':'#55A6FF','border-width':2.5,'background-color':'#55A6FF22'}},
    {selector:'edge',style:{
      'width':2,'line-color':'#3A3A3C','target-arrow-color':'#3A3A3C',
      'target-arrow-shape':'triangle','curve-style':'bezier',
      'label':'data(label)','font-size':'11px','color':'#8E8E93',
      'text-background-color':'#0F1017','text-background-opacity':1,'text-background-padding':'3px'}},
    {selector:'edge.dashed',style:{'line-style':'dashed'}},
    {selector:'edge.dotted',style:{'line-style':'dotted'}},
    {selector:'edge:selected',style:{'line-color':'#E8365D','target-arrow-color':'#E8365D'}},
    {selector:'node.actor',style:{'shape':'ellipse','background-color':'#FF9800','border-color':'#FF9800','color':'#fff'}},
    {selector:'node.usecase',style:{'shape':'ellipse','background-color':'#55A6FF22','border-color':'#55A6FF','color':'#CDD3DE'}},
    {selector:'node.boundary',style:{'shape':'rectangle','background-color':'#1E2130','border-color':'#55A6FF','border-style':'dashed','border-width':2,'color':'#CDD3DE'}},
    {selector:'node.interface-cls',style:{'shape':'rectangle','background-color':'#1E2130','border-color':'#9B59B6','border-style':'dashed','border-width':2,'color':'#9B59B6'}},
    {selector:'node.abstract-cls',style:{'shape':'roundrectangle','background-color':'#2C2C3E','border-color':'#E8365D','border-width':2,'color':'#E8365D'}},
    {selector:'node.er-attr',style:{'shape':'ellipse','background-color':'#1E2130','border-color':'#1BC47D','color':'#1BC47D','padding':'6px'}},
    {selector:'node.er-weak',style:{'shape':'rectangle','background-color':'#1E2130','border-color':'#F2A91D','border-style':'dashed','border-width':2,'color':'#F2A91D'}},
    {selector:'node.fork-join',style:{'shape':'rectangle','background-color':'#CDD3DE','border-color':'#CDD3DE','height':'14px','color':'#0F1017','font-size':'8px'}},
    {selector:'node.composite',style:{'shape':'roundrectangle','background-color':'#1A1A2E','border-color':'#55A6FF','border-width':2,'color':'#CDD3DE'}},
    {selector:'node.table-node',style:{'shape':'rectangle','background-color':'#1E2130','border-color':'#E8365D','border-width':2,'color':'#CDD3DE'}},
    {selector:'node.pk-field',style:{'shape':'roundrectangle','background-color':'#E8365D22','border-color':'#E8365D','color':'#E8365D','padding':'8px'}},
    {selector:'node.fk-field',style:{'shape':'roundrectangle','background-color':'#55A6FF22','border-color':'#55A6FF','color':'#55A6FF','padding':'8px'}},
    {selector:'node.seq-actor',style:{'shape':'ellipse','background-color':'#FF9800','border-color':'#FF9800','color':'#fff'}},
    {selector:'node.seq-obj',style:{'shape':'rectangle','background-color':'#2C2C3E','border-color':'#55A6FF','border-width':2,'color':'#CDD3DE'}},
    {selector:'node.fragment',style:{'shape':'rectangle','background-color':'#1BC47D11','border-color':'#1BC47D','border-style':'dashed','color':'#1BC47D'}},
    {selector:'edge.inheritance',style:{'target-arrow-shape':'triangle','target-arrow-fill':'hollow','target-arrow-color':'#CDD3DE','line-color':'#3A3A3C'}},
    {selector:'edge.composition',style:{'source-arrow-shape':'diamond','source-arrow-color':'#CDD3DE','line-color':'#3A3A3C','target-arrow-shape':'none'}},
    {selector:'edge.aggregation',style:{'source-arrow-shape':'diamond','source-arrow-fill':'hollow','source-arrow-color':'#CDD3DE','line-color':'#3A3A3C','target-arrow-shape':'none'}},
    {selector:'edge.dependency',style:{'line-style':'dashed','target-arrow-shape':'vee','target-arrow-color':'#8E8E93','line-color':'#8E8E93'}},
    {selector:'edge.extend-rel',style:{'line-style':'dashed','target-arrow-shape':'triangle','color':'#F2A91D','line-color':'#F2A91D','target-arrow-color':'#F2A91D','text-background-color':'#0F1017','text-background-opacity':1,'text-background-padding':'3px'}},
    {selector:'edge.include-rel',style:{'line-style':'dashed','target-arrow-shape':'triangle','color':'#55A6FF','line-color':'#55A6FF','target-arrow-color':'#55A6FF','text-background-color':'#0F1017','text-background-opacity':1,'text-background-padding':'3px'}},
    {selector:'edge.assoc-line',style:{'target-arrow-shape':'none','line-color':'#3A3A3C'}},
    {selector:'edge.one-to-one',style:{'color':'#1BC47D','line-color':'#1BC47D','target-arrow-shape':'none','text-background-color':'#0F1017','text-background-opacity':1,'text-background-padding':'3px'}},
    {selector:'edge.one-to-many',style:{'color':'#55A6FF','line-color':'#55A6FF','target-arrow-shape':'none','text-background-color':'#0F1017','text-background-opacity':1,'text-background-padding':'3px'}},
    {selector:'edge.many-to-many',style:{'color':'#F2A91D','line-color':'#F2A91D','target-arrow-shape':'none','text-background-color':'#0F1017','text-background-opacity':1,'text-background-padding':'3px'}}
  ],
  layout:{name:'breadthfirst',directed:true,padding:20,spacingFactor:1.4},
  userZoomingEnabled:true,userPanningEnabled:true,minZoom:0.2,maxZoom:4,
  autoungrabify:viewOnly,
});
if(!viewOnly){
cy.on('tap','node',function(e){
  if(!edgeMode)return;
  var node=e.target;
  if(!edgeSource){edgeSource=node;node.addClass('edge-source');}
  else{
    if(edgeSource.id()!==node.id()){cy.add({data:{id:'e'+Date.now(),source:edgeSource.id(),target:node.id(),label:''}});emitCode();}
    edgeSource.removeClass('edge-source');edgeSource=null;
  }
});
cy.on('tap',function(e){if(e.target===cy&&edgeMode&&edgeSource){edgeSource.removeClass('edge-source');edgeSource=null;}});
cy.on('dbltap','node',function(e){
  if(edgeMode)return;
  var node=e.target;
  if(typeof FlutterBridge!=='undefined')FlutterBridge.postMessage('__rename:'+node.id()+':'+node.data('label'));
});
function renameNode(id,newLabel){
  var n=cy.getElementById(id);
  if(!n.empty()){n.data('label',newLabel);emitCode();}
}
cy.on('free','node',function(){emitCode();});
cy.on('remove',function(){emitCode();});
cy.on('add','edge',function(){emitCode();});
}

function addNodeOfType(shape,cls,defaultLabel){
  nodeCounter++;
  var id=(cls||'N')+nodeCounter;
  var el={data:{id:id,label:defaultLabel||'Nodo '+nodeCounter}};
  if(cls)el.classes=cls;
  cy.add(el);
  cy.layout({name:'breadthfirst',directed:true,padding:20}).run();
  emitCode();
}
function addEdgeOfType(style){
  if(cy.nodes().length<2){alert('Necesitas al menos 2 nodos.');return;}
  var all=cy.nodes();
  var src=all[0].id(),tgt=all[1].id();
  var el={data:{id:'e'+Date.now(),source:src,target:tgt,label:''}};
  if(style)el.classes=style;
  cy.add(el);emitCode();
}
function addEdgeLabeled(cls,lbl){
  if(cy.nodes().length<2){alert('Necesitas al menos 2 nodos.');return;}
  var all=cy.nodes();
  var src=all[0].id(),tgt=all[1].id();
  var el={data:{id:'e'+Date.now(),source:src,target:tgt,label:lbl}};
  if(cls)el.classes=cls;
  cy.add(el);emitCode();
}
function addSelfEdge(){
  if(cy.nodes().length<1){alert('Necesitas al menos 1 nodo.');return;}
  var n=cy.nodes(':selected').first();
  if(n.empty())n=cy.nodes().first();
  cy.add({data:{id:'e'+Date.now(),source:n.id(),target:n.id(),label:'self'}});
  emitCode();
}
function toggleEdgeMode(){
  edgeMode=!edgeMode;
  if(!edgeMode&&edgeSource){edgeSource.removeClass('edge-source');edgeSource=null;}
  if(typeof FlutterBridge!=='undefined')FlutterBridge.postMessage('__edgeMode:'+edgeMode);
}
function deleteSelected(){cy.elements(':selected').remove();emitCode();}
function layoutAuto(){cy.layout({name:'breadthfirst',directed:true,padding:20,spacingFactor:1.4}).run();}
function fitView(){cy.fit(undefined,20);}
function emitCode(){
  var lines=['graph TD'];
  var nodeIds={};
  cy.nodes().forEach(function(n){
    nodeIds[n.id()]=true;
    var lbl=n.data('label')||n.id();
    lines.push(lbl===n.id()?'  '+n.id():'  '+n.id()+'["'+lbl+'"]');
  });
  cy.edges().forEach(function(e){
    var src=e.data('source'),tgt=e.data('target'),lbl=e.data('label')||'';
    if(!nodeIds[src]||!nodeIds[tgt])return;
    lines.push(lbl?'  '+src+' -->|'+lbl+'| '+tgt:'  '+src+' --> '+tgt);
  });
  if(typeof FlutterBridge!=='undefined')FlutterBridge.postMessage(lines.join('\n'));
}
</script></body></html>''';

    return head + escaped + tail;
  }

  // ────────────────────────────────────────────────────────────────────────
  // Component palette items — specific per diagram type
  // ────────────────────────────────────────────────────────────────────────
  List<_ComponentItem> get _components {
    final canvas = <_ComponentItem>[
      _ComponentItem(
        label: 'Conectar',
        icon: Icons.linear_scale_rounded,
        color: const Color(0xFF55A6FF),
        onTap: () => _jsCall('toggleEdgeMode()'),
      ),
      _ComponentItem(
        label: 'Eliminar',
        icon: Icons.delete_outline_rounded,
        color: fsdPink,
        onTap: () => _jsCall('deleteSelected()'),
      ),
      _ComponentItem(
        label: 'Auto layout',
        icon: Icons.auto_fix_high_rounded,
        color: const Color(0xFF1BC47D),
        onTap: () => _jsCall('layoutAuto()'),
      ),
      _ComponentItem(
        label: 'Ajustar',
        icon: Icons.fit_screen_rounded,
        color: const Color(0xFF55A6FF),
        onTap: () => _jsCall('fitView()'),
      ),
    ];

    switch (_type) {
      // ── Diagrama de flujo ──────────────────────────────────────────────
      case 'flowchart':
        return [
          _ComponentItem(label: 'Inicio', icon: Icons.play_circle_outline_rounded, color: fsdPink, onTap: () => _jsCall("addNodeOfType('ellipse','start','Inicio')")),
          _ComponentItem(label: 'Fin', icon: Icons.stop_circle_outlined, color: const Color(0xFF1BC47D), onTap: () => _jsCall("addNodeOfType('ellipse','end','Fin')")),
          _ComponentItem(label: 'Proceso', icon: Icons.crop_square_rounded, color: const Color(0xFF55A6FF), onTap: () => _jsCall("addNodeOfType('roundrectangle',null,'Proceso')")),
          _ComponentItem(label: 'Decisión', icon: Icons.diamond_outlined, color: const Color(0xFFF2A91D), onTap: () => _jsCall("addNodeOfType('diamond','decision','¿Condición?')")),
          _ComponentItem(label: 'Nota', icon: Icons.sticky_note_2_outlined, color: const Color(0xFFF2A91D), onTap: () => _jsCall("addNodeOfType('rectangle','note','Nota')")),
          _ComponentItem(label: 'Flecha', icon: Icons.arrow_forward_rounded, color: const Color(0xFF8E8E93), onTap: () => _jsCall('addEdgeOfType(null)')),
          _ComponentItem(label: 'Punteada', icon: Icons.more_horiz_rounded, color: const Color(0xFF8E8E93), onTap: () => _jsCall("addEdgeOfType('dashed')")),
          _ComponentItem(label: 'Sin flecha', icon: Icons.horizontal_rule_rounded, color: const Color(0xFF3A3A3C), onTap: () => _jsCall("addEdgeOfType('assoc-line')")),
          ...canvas,
        ];

      // ── Actividad ──────────────────────────────────────────────────────
      case 'activity':
        return [
          _ComponentItem(label: 'Inicio', icon: Icons.play_circle_outline_rounded, color: fsdPink, onTap: () => _jsCall("addNodeOfType('ellipse','start','Inicio')")),
          _ComponentItem(label: 'Fin', icon: Icons.stop_circle_outlined, color: const Color(0xFF1BC47D), onTap: () => _jsCall("addNodeOfType('ellipse','end','Fin')")),
          _ComponentItem(label: 'Acción', icon: Icons.crop_square_rounded, color: const Color(0xFF55A6FF), onTap: () => _jsCall("addNodeOfType('roundrectangle',null,'Acción')")),
          _ComponentItem(label: 'Decisión', icon: Icons.diamond_outlined, color: const Color(0xFFF2A91D), onTap: () => _jsCall("addNodeOfType('diamond','decision','¿Condición?')")),
          _ComponentItem(label: 'Fork/Join', icon: Icons.compare_arrows_rounded, color: const Color(0xFFCDD3DE), onTap: () => _jsCall("addNodeOfType('rectangle','fork-join','Fork')")),
          _ComponentItem(label: 'Nota', icon: Icons.sticky_note_2_outlined, color: const Color(0xFFF2A91D), onTap: () => _jsCall("addNodeOfType('rectangle','note','Nota')")),
          _ComponentItem(label: 'Transición', icon: Icons.arrow_forward_rounded, color: const Color(0xFF8E8E93), onTap: () => _jsCall('addEdgeOfType(null)')),
          _ComponentItem(label: 'Punteada', icon: Icons.more_horiz_rounded, color: const Color(0xFF8E8E93), onTap: () => _jsCall("addEdgeOfType('dashed')")),
          ...canvas,
        ];

      // ── Caso de uso ────────────────────────────────────────────────────
      case 'use-case':
        return [
          _ComponentItem(label: 'Actor', icon: Icons.person_outline_rounded, color: const Color(0xFFFF9800), onTap: () => _jsCall("addNodeOfType('ellipse','actor','Actor')")),
          _ComponentItem(label: 'Caso de Uso', icon: Icons.radio_button_unchecked_rounded, color: const Color(0xFF55A6FF), onTap: () => _jsCall("addNodeOfType('ellipse','usecase','Caso de Uso')")),
          _ComponentItem(label: 'Sistema', icon: Icons.crop_square_rounded, color: const Color(0xFFCDD3DE), onTap: () => _jsCall("addNodeOfType('rectangle','boundary','Sistema')")),
          _ComponentItem(label: 'Nota', icon: Icons.sticky_note_2_outlined, color: const Color(0xFFF2A91D), onTap: () => _jsCall("addNodeOfType('rectangle','note','Nota')")),
          _ComponentItem(label: 'Asociación', icon: Icons.arrow_forward_rounded, color: const Color(0xFF8E8E93), onTap: () => _jsCall('addEdgeOfType(null)')),
          _ComponentItem(label: 'Include', icon: Icons.subdirectory_arrow_right_rounded, color: const Color(0xFF55A6FF), onTap: () => _jsCall("addEdgeLabeled('include-rel','<<include>>')")),
          _ComponentItem(label: 'Extend', icon: Icons.call_split_rounded, color: const Color(0xFFF2A91D), onTap: () => _jsCall("addEdgeLabeled('extend-rel','<<extend>>')")),
          _ComponentItem(label: 'Sin flecha', icon: Icons.horizontal_rule_rounded, color: const Color(0xFF3A3A3C), onTap: () => _jsCall("addEdgeOfType('assoc-line')")),
          ...canvas,
        ];

      // ── Diagrama de clases ─────────────────────────────────────────────
      case 'class':
        return [
          _ComponentItem(label: 'Clase', icon: Icons.crop_square_rounded, color: const Color(0xFF55A6FF), onTap: () => _jsCall("addNodeOfType('roundrectangle',null,'Clase')")),
          _ComponentItem(label: 'Interfaz', icon: Icons.layers_outlined, color: const Color(0xFF9B59B6), onTap: () => _jsCall("addNodeOfType('rectangle','interface-cls','<<interface>>')")),
          _ComponentItem(label: 'Abstracta', icon: Icons.rectangle_outlined, color: fsdPink, onTap: () => _jsCall("addNodeOfType('roundrectangle','abstract-cls','<<abstract>>')")),
          _ComponentItem(label: 'Nota', icon: Icons.sticky_note_2_outlined, color: const Color(0xFFF2A91D), onTap: () => _jsCall("addNodeOfType('rectangle','note','Nota')")),
          _ComponentItem(label: 'Herencia', icon: Icons.call_merge_rounded, color: const Color(0xFFCDD3DE), onTap: () => _jsCall("addEdgeOfType('inheritance')")),
          _ComponentItem(label: 'Composición', icon: Icons.diamond_rounded, color: const Color(0xFF55A6FF), onTap: () => _jsCall("addEdgeOfType('composition')")),
          _ComponentItem(label: 'Agregación', icon: Icons.diamond_outlined, color: const Color(0xFF55A6FF), onTap: () => _jsCall("addEdgeOfType('aggregation')")),
          _ComponentItem(label: 'Dependencia', icon: Icons.more_horiz_rounded, color: const Color(0xFF8E8E93), onTap: () => _jsCall("addEdgeOfType('dependency')")),
          _ComponentItem(label: 'Asociación', icon: Icons.arrow_forward_rounded, color: const Color(0xFF8E8E93), onTap: () => _jsCall('addEdgeOfType(null)')),
          ...canvas,
        ];

      // ── Secuencia ──────────────────────────────────────────────────────
      case 'sequence':
        return [
          _ComponentItem(label: 'Actor', icon: Icons.person_outline_rounded, color: const Color(0xFFFF9800), onTap: () => _jsCall("addNodeOfType('ellipse','seq-actor','Actor')")),
          _ComponentItem(label: 'Objeto', icon: Icons.rectangle_outlined, color: const Color(0xFF55A6FF), onTap: () => _jsCall("addNodeOfType('rectangle','seq-obj','Objeto')")),
          _ComponentItem(label: 'Fragmento', icon: Icons.flip_to_front_outlined, color: const Color(0xFF1BC47D), onTap: () => _jsCall("addNodeOfType('rectangle','fragment','Fragment')")),
          _ComponentItem(label: 'Nota', icon: Icons.sticky_note_2_outlined, color: const Color(0xFFF2A91D), onTap: () => _jsCall("addNodeOfType('rectangle','note','Nota')")),
          _ComponentItem(label: 'Mensaje', icon: Icons.arrow_forward_rounded, color: const Color(0xFF8E8E93), onTap: () => _jsCall('addEdgeOfType(null)')),
          _ComponentItem(label: 'Retorno', icon: Icons.keyboard_return_rounded, color: const Color(0xFF55A6FF), onTap: () => _jsCall("addEdgeOfType('dashed')")),
          _ComponentItem(label: 'Asíncrono', icon: Icons.double_arrow_rounded, color: const Color(0xFFCDD3DE), onTap: () => _jsCall("addEdgeOfType('dotted')")),
          _ComponentItem(label: 'Auto-msg', icon: Icons.refresh_rounded, color: const Color(0xFFF2A91D), onTap: () => _jsCall('addSelfEdge()')),
          ...canvas,
        ];

      // ── Diagrama ER ────────────────────────────────────────────────────
      case 'er':
        return [
          _ComponentItem(label: 'Entidad', icon: Icons.crop_square_rounded, color: const Color(0xFF55A6FF), onTap: () => _jsCall("addNodeOfType('rectangle',null,'Entidad')")),
          _ComponentItem(label: 'Atributo', icon: Icons.radio_button_unchecked_rounded, color: const Color(0xFF1BC47D), onTap: () => _jsCall("addNodeOfType('ellipse','er-attr','atributo')")),
          _ComponentItem(label: 'Relación', icon: Icons.diamond_outlined, color: const Color(0xFFF2A91D), onTap: () => _jsCall("addNodeOfType('diamond','decision','relación')")),
          _ComponentItem(label: 'E. Débil', icon: Icons.crop_din_rounded, color: const Color(0xFFF2A91D), onTap: () => _jsCall("addNodeOfType('rectangle','er-weak','E. Débil')")),
          _ComponentItem(label: 'Línea', icon: Icons.horizontal_rule_rounded, color: const Color(0xFF8E8E93), onTap: () => _jsCall("addEdgeOfType('assoc-line')")),
          _ComponentItem(label: '1:1', icon: Icons.looks_one_outlined, color: const Color(0xFF1BC47D), onTap: () => _jsCall("addEdgeLabeled('one-to-one','1:1')")),
          _ComponentItem(label: '1:N', icon: Icons.looks_two_outlined, color: const Color(0xFF55A6FF), onTap: () => _jsCall("addEdgeLabeled('one-to-many','1:N')")),
          _ComponentItem(label: 'N:M', icon: Icons.all_inclusive_rounded, color: const Color(0xFFF2A91D), onTap: () => _jsCall("addEdgeLabeled('many-to-many','N:M')")),
          ...canvas,
        ];

      // ── Diagrama de estados ────────────────────────────────────────────
      case 'state':
        return [
          _ComponentItem(label: 'Inicial', icon: Icons.play_circle_filled_rounded, color: fsdPink, onTap: () => _jsCall("addNodeOfType('ellipse','start','●')")),
          _ComponentItem(label: 'Estado', icon: Icons.crop_square_rounded, color: const Color(0xFF55A6FF), onTap: () => _jsCall("addNodeOfType('roundrectangle',null,'Estado')")),
          _ComponentItem(label: 'Final', icon: Icons.stop_circle_rounded, color: const Color(0xFF1BC47D), onTap: () => _jsCall("addNodeOfType('ellipse','end','◉')")),
          _ComponentItem(label: 'Compuesto', icon: Icons.view_quilt_outlined, color: const Color(0xFF55A6FF), onTap: () => _jsCall("addNodeOfType('roundrectangle','composite','Compuesto')")),
          _ComponentItem(label: 'Nota', icon: Icons.sticky_note_2_outlined, color: const Color(0xFFF2A91D), onTap: () => _jsCall("addNodeOfType('rectangle','note','Nota')")),
          _ComponentItem(label: 'Transición', icon: Icons.arrow_forward_rounded, color: const Color(0xFF8E8E93), onTap: () => _jsCall('addEdgeOfType(null)')),
          _ComponentItem(label: 'Interna', icon: Icons.more_horiz_rounded, color: const Color(0xFF8E8E93), onTap: () => _jsCall("addEdgeOfType('dashed')")),
          _ComponentItem(label: 'Auto-trans.', icon: Icons.refresh_rounded, color: const Color(0xFFF2A91D), onTap: () => _jsCall('addSelfEdge()')),
          ...canvas,
        ];

      // ── Modelo Relacional ──────────────────────────────────────────────
      case 'mr':
        return [
          _ComponentItem(label: 'Tabla', icon: Icons.table_chart_outlined, color: const Color(0xFF55A6FF), onTap: () => _jsCall("addNodeOfType('rectangle','table-node','Tabla')")),
          _ComponentItem(label: 'PK', icon: Icons.vpn_key_outlined, color: fsdPink, onTap: () => _jsCall("addNodeOfType('roundrectangle','pk-field','PK: id')")),
          _ComponentItem(label: 'FK', icon: Icons.link_rounded, color: const Color(0xFF55A6FF), onTap: () => _jsCall("addNodeOfType('roundrectangle','fk-field','FK: id')")),
          _ComponentItem(label: 'Campo', icon: Icons.text_fields_rounded, color: const Color(0xFFCDD3DE), onTap: () => _jsCall("addNodeOfType('roundrectangle',null,'campo')")),
          _ComponentItem(label: '1:1', icon: Icons.looks_one_outlined, color: const Color(0xFF1BC47D), onTap: () => _jsCall("addEdgeLabeled('one-to-one','1:1')")),
          _ComponentItem(label: '1:N', icon: Icons.looks_two_outlined, color: const Color(0xFF55A6FF), onTap: () => _jsCall("addEdgeLabeled('one-to-many','1:N')")),
          _ComponentItem(label: 'N:M', icon: Icons.all_inclusive_rounded, color: const Color(0xFFF2A91D), onTap: () => _jsCall("addEdgeLabeled('many-to-many','N:M')")),
          _ComponentItem(label: 'Relación', icon: Icons.arrow_forward_rounded, color: const Color(0xFF8E8E93), onTap: () => _jsCall('addEdgeOfType(null)')),
          ...canvas,
        ];

      // ── Genérico / fallback ────────────────────────────────────────────
      default:
        return [
          _ComponentItem(label: 'Nodo', icon: Icons.crop_square_rounded, color: const Color(0xFF55A6FF), onTap: () => _jsCall("addNodeOfType('roundrectangle',null,null)")),
          _ComponentItem(label: 'Inicio', icon: Icons.play_circle_outline_rounded, color: fsdPink, onTap: () => _jsCall("addNodeOfType('ellipse','start','Inicio')")),
          _ComponentItem(label: 'Fin', icon: Icons.stop_circle_outlined, color: const Color(0xFF1BC47D), onTap: () => _jsCall("addNodeOfType('ellipse','end','Fin')")),
          _ComponentItem(label: 'Decisión', icon: Icons.diamond_outlined, color: const Color(0xFFF2A91D), onTap: () => _jsCall("addNodeOfType('diamond','decision','¿Condición?')")),
          _ComponentItem(label: 'Nota', icon: Icons.sticky_note_2_outlined, color: const Color(0xFFF2A91D), onTap: () => _jsCall("addNodeOfType('rectangle','note','Nota')")),
          _ComponentItem(label: 'Flecha', icon: Icons.arrow_forward_rounded, color: const Color(0xFF8E8E93), onTap: () => _jsCall('addEdgeOfType(null)')),
          _ComponentItem(label: 'Punteada', icon: Icons.more_horiz_rounded, color: const Color(0xFF8E8E93), onTap: () => _jsCall("addEdgeOfType('dashed')")),
          _ComponentItem(label: 'Puntos', icon: Icons.more_horiz_rounded, color: const Color(0xFF3A3A3C), onTap: () => _jsCall("addEdgeOfType('dotted')")),
          ...canvas,
        ];
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final name = widget.diagramName ?? 'Diagrama';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            _TopBar(
              name: name,
              dirty: _dirty,
              saving: _saving,
              onBack: () async {
                _autosaveTimer?.cancel();
                if (_dirty) await _save();
                if (mounted) context.pop();
              },
              onSave: _save,
            ),

            // ── Canvas ───────────────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_canvasLoading)
                    const Center(
                      child: CircularProgressIndicator(
                          color: fsdPink, strokeWidth: 2.5),
                    ),
                ],
              ),
            ),

            // ── Component panel ──────────────────────────────────────────
            _ComponentPanel(
              open: _panelOpen,
              components: _components,
              onToggle: () => setState(() => _panelOpen = !_panelOpen),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String name;
  final bool dirty;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onSave;

  const _TopBar({
    required this.name,
    required this.dirty,
    required this.saving,
    required this.onBack,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          // Back
          IconButton(
            tooltip: 'Volver',
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: cs.onSurface, size: 18),
            onPressed: onBack,
          ),
          // Name
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          // Save button
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: saving
                ? const SizedBox(
                    width: 34,
                    height: 34,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: fsdPink, strokeWidth: 2.2),
                      ),
                    ),
                  )
                : FilledButton(
                    onPressed: onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: fsdPink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 34),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Guardar',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Component panel ─────────────────────────────────────────────────────────

class _ComponentPanel extends StatelessWidget {
  final bool open;
  final List<_ComponentItem> components;
  final VoidCallback onToggle;

  const _ComponentPanel({
    required this.open,
    required this.components,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top border line ───────────────────────────────────────────
          Container(height: 1, color: cs.outlineVariant),

          // ── Components grid (slides in above the arrow) ───────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: open ? 164.0 : 0,
            child: GridView.count(
              crossAxisCount: 4,
              childAspectRatio: 1.15,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              physics: const BouncingScrollPhysics(),
              children: components
                  .map((c) => _ComponentTile(item: c))
                  .toList(),
            ),
          ),

          // ── Arrow toggle (centered, full-width tap area) ───────────────
          GestureDetector(
            onTap: onToggle,
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: AnimatedRotation(
                  turns: open ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(Icons.keyboard_arrow_up_rounded,
                      color: fsdTextGrey, size: 26),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ComponentItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _ComponentTile extends StatelessWidget {
  final _ComponentItem item;
  const _ComponentTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 20, color: item.color),
            const SizedBox(height: 4),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: fsdTextGrey,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
