import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/services/auth_service.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';

const _pink = Color(0xFFE8365D);
const _cardBg = Color(0xFF191B24);
const _borderColor = Color(0xFF2A2D3A);
const _textGrey = Color(0xFF8E8E93);

class TeamMeetingAiResultScreen extends StatefulWidget {
  final int sessionId;

  const TeamMeetingAiResultScreen({super.key, required this.sessionId});

  @override
  State<TeamMeetingAiResultScreen> createState() =>
      _TeamMeetingAiResultScreenState();
}

class _TeamMeetingAiResultScreenState extends State<TeamMeetingAiResultScreen> {
  bool loading = true;
  bool processingAi = false;
  bool applyingToSrs = false;

  String? errorMessage;
  String? successMessage;

  Map<String, dynamic>? sessionData;

  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _transcriptController = TextEditingController();
  final TextEditingController _functionalController = TextEditingController();
  final TextEditingController _nonFunctionalController =
      TextEditingController();
  final TextEditingController _tasksController = TextEditingController();

  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _transcriptController.dispose();
    _functionalController.dispose();
    _nonFunctionalController.dispose();
    _tasksController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    try {
      final detail = await ApiService.getTeamMeetingDetail(widget.sessionId);

      if (!mounted) return;

      _setControllersFromSession(detail, force: true);

      setState(() {
        sessionData = detail;
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _setControllersFromSession(
    Map<String, dynamic> detail, {
    bool force = false,
  }) {
    final summary = (detail['summary'] ?? '').toString();
    final transcript = (detail['transcript'] ?? '').toString();
    final functional = _stringList(detail['functional_requirements']);
    final nonFunctional = _stringList(detail['non_functional_requirements']);
    final tasks = _stringList(detail['tasks']);

    if (!_controllersInitialized || force) {
      _summaryController.text = summary;
      _transcriptController.text = transcript;
      _functionalController.text = functional.join('\n');
      _nonFunctionalController.text = nonFunctional.join('\n');
      _tasksController.text = tasks.join('\n');
      _controllersInitialized = true;
      return;
    }

    _summaryController.text = summary;
    _transcriptController.text = transcript;
    _functionalController.text = functional.join('\n');
    _nonFunctionalController.text = nonFunctional.join('\n');
    _tasksController.text = tasks.join('\n');
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  List<String> _linesToList(String value) {
    return value
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  bool get _isHost {
    final hostUserId = sessionData?['host_user'];
    return hostUserId == AuthService.userId;
  }

  String get _aiStatus {
    return (sessionData?['ai_processing_status'] ?? 'pending').toString();
  }

  String get _recordingStatus {
    return (sessionData?['recording_status'] ?? '').toString();
  }

  bool get _hasAiResult {
    return _summaryController.text.trim().isNotEmpty ||
        _transcriptController.text.trim().isNotEmpty ||
        _functionalController.text.trim().isNotEmpty ||
        _nonFunctionalController.text.trim().isNotEmpty ||
        _tasksController.text.trim().isNotEmpty;
  }

  Future<void> _processWithAi() async {
    if (processingAi) return;

    setState(() {
      processingAi = true;
      errorMessage = null;
      successMessage = null;
    });

    try {
      final result = await ApiService.processTeamMeetingAi(widget.sessionId);

      if (!mounted) return;

      setState(() {
        sessionData = result;
        successMessage = 'La reunión fue procesada correctamente con IA.';
      });

      _setControllersFromSession(result, force: true);
    } catch (e) {
      if (!mounted) return;

      final clean = e.toString().replaceFirst('Exception: ', '');

      String friendly = clean;
      if (clean.contains('La grabación aún se está finalizando')) {
        friendly =
            'La grabación todavía se está cerrando. Espera unos segundos e inténtalo de nuevo.';
      } else if (clean.contains('todavía no se encontró el archivo de audio')) {
        friendly =
            'El audio aún no aparece listo en la nube. Espera unos segundos y vuelve a intentarlo.';
      }

      setState(() {
        errorMessage = friendly;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        processingAi = false;
      });
    }
  }

  Future<void> _applyToSrs() async {
    if (applyingToSrs) return;

    setState(() {
      applyingToSrs = true;
      errorMessage = null;
      successMessage = null;
    });

    try {
      final result = await ApiService.applyTeamMeetingAiToSrs(
        sessionId: widget.sessionId,
        summary: _summaryController.text.trim(),
        transcript: _transcriptController.text.trim(),
        functionalRequirements: _linesToList(_functionalController.text),
        nonFunctionalRequirements: _linesToList(_nonFunctionalController.text),
        tasks: _linesToList(_tasksController.text),
      );

      if (!mounted) return;

      final session = Map<String, dynamic>.from(result['session'] ?? {});

      setState(() {
        sessionData = session.isNotEmpty ? session : sessionData;
        successMessage = (result['detail'] ?? 'Resultados aplicados al SRS.')
            .toString();
      });

      if (session.isNotEmpty) {
        _setControllersFromSession(session, force: true);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;

      setState(() {
        applyingToSrs = false;
      });
    }
  }

  Widget _buildStatusCard() {
    final projectName = (sessionData?['project_name'] ?? '').toString();
    final workspaceName = (sessionData?['workspace_name'] ?? '').toString();
    final title = (sessionData?['title'] ?? 'Resultado IA').toString();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$projectName • $workspaceName',
            style: const TextStyle(color: _textGrey, height: 1.45),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusChip(text: 'Grabación: $_recordingStatus'),
              _StatusChip(text: 'IA: $_aiStatus'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (!_isHost) {
      return const _Card(
        child: Text(
          'Solo el líder de la reunión puede procesar y aplicar los resultados al SRS.',
          style: TextStyle(color: _textGrey, height: 1.45),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: processingAi ? null : _processWithAi,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(
              processingAi ? 'Procesando...' : 'Procesar con IA',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _pink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: (!_hasAiResult || applyingToSrs) ? null : _applyToSrs,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              applyingToSrs ? 'Guardando...' : 'Guardar en SRS',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: _pink),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditor({
    required String title,
    required TextEditingController controller,
    int minLines = 3,
    int maxLines = 8,
  }) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1E2030),
              hintText: 'Sin contenido',
              hintStyle: const TextStyle(color: _textGrey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _pink),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedback() {
    if (errorMessage == null && successMessage == null) {
      return const SizedBox.shrink();
    }

    final isError = errorMessage != null;
    final text = isError ? errorMessage! : successMessage!;
    final color = isError ? _pink : const Color(0xFF1BC47D);
    final bg = isError ? const Color(0x22E8365D) : const Color(0x221BC47D);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainAppShell(
      selectedItem: null,
      eyebrow: 'Resultado IA',
      titleWhite: 'Revisión de ',
      titlePink: 'reunión',
      description:
          'Procesa la grabación de la llamada grupal, revisa el resultado y decide qué guardar en el SRS.',
      showTopNav: false,
      child: loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 80),
                child: CircularProgressIndicator(color: _pink),
              ),
            )
          : errorMessage != null && sessionData == null
          ? _Card(
              child: Column(
                children: [
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: _pink,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loadSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pink,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 18),
                  _buildActionButtons(),
                  const SizedBox(height: 18),
                  _buildFeedback(),
                  if (errorMessage != null || successMessage != null)
                    const SizedBox(height: 18),
                  _buildEditor(
                    title: 'Resumen',
                    controller: _summaryController,
                    minLines: 3,
                    maxLines: 6,
                  ),
                  const SizedBox(height: 14),
                  _buildEditor(
                    title: 'Transcripción',
                    controller: _transcriptController,
                    minLines: 8,
                    maxLines: 14,
                  ),
                  const SizedBox(height: 14),
                  _buildEditor(
                    title: 'Requerimientos funcionales',
                    controller: _functionalController,
                    minLines: 4,
                    maxLines: 8,
                  ),
                  const SizedBox(height: 14),
                  _buildEditor(
                    title: 'Requerimientos no funcionales',
                    controller: _nonFunctionalController,
                    minLines: 4,
                    maxLines: 8,
                  ),
                  const SizedBox(height: 14),
                  _buildEditor(
                    title: 'Tareas detectadas',
                    controller: _tasksController,
                    minLines: 4,
                    maxLines: 8,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/team-meetings'),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text(
                        'Volver a reuniones',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: _borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
      ),
      child: child,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;

  const _StatusChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x22E8365D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x55E8365D)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _pink,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
