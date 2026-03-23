import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';

const _pink = Color(0xFFE8365D);
const _cardBg = Color(0xFF191B24);
const _borderColor = Color(0xFF2A2D3A);
const _textGrey = Color(0xFF8E8E93);

enum MeetingModeState { idle, recording, processing, ready }

class MeetingModeScreen extends StatefulWidget {
  const MeetingModeScreen({super.key});

  @override
  State<MeetingModeScreen> createState() => _MeetingModeScreenState();
}

class _MeetingModeScreenState extends State<MeetingModeScreen> {
  final AudioRecorder _recorder = AudioRecorder();

  MeetingModeState state = MeetingModeState.idle;

  List<dynamic> projects = [];
  bool loadingProjects = true;
  String? selectedProjectId;

  String? audioPath;
  Duration recordingDuration = Duration.zero;
  Timer? _timer;

  String transcript = '';
  String summary = '';
  String functionalRequirements = '';
  String nonFunctionalRequirements = '';
  String detectedTasks = '';

  String? errorMessage;
  String? successMessage;
  String? processingInfo;

  bool savedToBackend = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    try {
      final data = await ApiService.getProjects();

      if (!mounted) return;

      setState(() {
        projects = data;
        loadingProjects = false;
        if (projects.isNotEmpty) {
          selectedProjectId = projects.first['id'].toString();
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loadingProjects = false;
        errorMessage = 'No se pudieron cargar los proyectos.';
      });
    }
  }

  Future<String> _buildAudioFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/meeting_mode');

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${folder.path}/meeting_$timestamp.m4a';
  }

  Future<void> startRecording() async {
    setState(() {
      errorMessage = null;
      successMessage = null;
      processingInfo = null;
      savedToBackend = false;
    });

    if (selectedProjectId == null || selectedProjectId!.isEmpty) {
      setState(() {
        errorMessage = 'Selecciona un proyecto antes de grabar.';
      });
      return;
    }

    try {
      final hasPermission = await _recorder.hasPermission();

      if (!hasPermission) {
        setState(() {
          errorMessage =
              'No se concedió permiso al micrófono. Revisa los permisos de la app.';
        });
        return;
      }

      final path = await _buildAudioFilePath();

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      _timer?.cancel();
      recordingDuration = Duration.zero;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          recordingDuration += const Duration(seconds: 1);
        });
      });

      setState(() {
        audioPath = path;
        state = MeetingModeState.recording;
      });
    } catch (_) {
      setState(() {
        errorMessage = 'No se pudo iniciar la grabación.';
      });
    }
  }

  Future<void> stopRecording() async {
    try {
      _timer?.cancel();

      final path = await _recorder.stop();

      if (path == null || path.isEmpty) {
        setState(() {
          state = MeetingModeState.idle;
          errorMessage = 'No se pudo guardar el audio grabado.';
        });
        return;
      }

      setState(() {
        audioPath = path;
        state = MeetingModeState.processing;
        processingInfo = 'Intentando procesar reunión con backend...';
      });

      await _processMeeting();
    } catch (_) {
      setState(() {
        state = MeetingModeState.idle;
        errorMessage = 'Ocurrió un error al detener la grabación.';
      });
    }
  }

  Future<void> _processMeeting() async {
    if (audioPath == null || selectedProjectId == null) {
      setState(() {
        state = MeetingModeState.idle;
        errorMessage = 'Faltan datos para procesar la reunión.';
      });
      return;
    }

    final file = File(audioPath!);

    try {
      if (!await file.exists()) {
        throw Exception('El archivo de audio no existe.');
      }

      final result = await ApiService.processMeetingAudio(
        projectId: int.parse(selectedProjectId!),
        audioFile: file,
      );

      if (!mounted) return;

      final transcriptValue = (result['transcript'] ?? '').toString();
      final summaryValue = (result['summary'] ?? '').toString();

      final functional = List<dynamic>.from(
        result['functional_requirements'] ??
            result['suggested_requirements']?['functional'] ??
            [],
      );

      final nonFunctional = List<dynamic>.from(
        result['non_functional_requirements'] ??
            result['suggested_requirements']?['non_functional'] ??
            [],
      );

      final tasks = List<dynamic>.from(
        result['tasks'] ?? result['detected_tasks'] ?? [],
      );

      setState(() {
        state = MeetingModeState.ready;
        transcript = transcriptValue;
        summary = summaryValue;
        functionalRequirements = functional.map((e) => e.toString()).join('\n');
        nonFunctionalRequirements = nonFunctional
            .map((e) => e.toString())
            .join('\n');
        detectedTasks = tasks.map((e) => e.toString()).join('\n');
        processingInfo = 'Resultado generado desde backend.';
        successMessage = 'La reunión fue procesada correctamente.';
      });
    } catch (_) {
      await _simulateMeetingProcessing();
    }
  }

  Future<void> _simulateMeetingProcessing() async {
    await Future.delayed(const Duration(seconds: 2));

    final selectedProject = projects.firstWhere(
      (p) => p['id'].toString() == selectedProjectId,
      orElse: () => <String, dynamic>{},
    );

    final projectName = (selectedProject['name'] ?? 'Proyecto seleccionado')
        .toString();

    final date = DateTime.now();
    final formattedDate =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    final file = audioPath != null ? File(audioPath!) : null;
    final fileSizeKb = (file != null && await file.exists())
        ? ((await file.length()) / 1024).toStringAsFixed(1)
        : '0';

    if (!mounted) return;

    setState(() {
      state = MeetingModeState.ready;

      transcript =
          'Transcripción provisional generada localmente.\n\n'
          'Proyecto: $projectName\n'
          'Fecha: $formattedDate\n'
          'Duración grabada: ${_formatDuration(recordingDuration)}\n'
          'Archivo: ${audioPath?.split('/').last ?? 'audio.m4a'}\n'
          'Tamaño aproximado: $fileSizeKb KB\n\n'
          'No se encontró procesamiento de backend disponible, por lo que se generó un borrador local para continuar las pruebas del flujo móvil.';

      summary =
          'Se registró una reunión asociada al proyecto "$projectName". '
          'La grabación quedó almacenada correctamente y el sistema preparó un borrador inicial para revisión.';

      functionalRequirements =
          '- El sistema debe permitir registrar acuerdos de reunión.\n'
          '- El sistema debe asociar una reunión a un proyecto.\n'
          '- El sistema debe permitir revisar y editar el resultado antes de guardarlo.';

      nonFunctionalRequirements =
          '- El sistema debe procesar la reunión en segundo plano.\n'
          '- La grabación debe almacenarse temporalmente en el dispositivo.\n'
          '- La interfaz debe mostrar claramente estados de grabación y procesamiento.';

      detectedTasks =
          '- Revisar la reunión y validar el resumen.\n'
          '- Confirmar los requerimientos detectados.\n'
          '- Conectar el procesamiento real con backend.';

      processingInfo =
          'Backend de reuniones no disponible todavía. Se generó resultado provisional local.';
      successMessage = null;
      errorMessage = null;
    });
  }

  List<String> _textToList(String value) {
    return value
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> saveMeetingResult() async {
    setState(() {
      successMessage = null;
      errorMessage = null;
    });

    if (selectedProjectId == null || selectedProjectId!.isEmpty) {
      setState(() {
        errorMessage = 'Debes seleccionar un proyecto.';
      });
      return;
    }

    if (summary.trim().isEmpty &&
        transcript.trim().isEmpty &&
        functionalRequirements.trim().isEmpty &&
        nonFunctionalRequirements.trim().isEmpty &&
        detectedTasks.trim().isEmpty) {
      setState(() {
        errorMessage = 'No hay contenido para guardar.';
      });
      return;
    }

    try {
      await ApiService.saveMeetingResult(
        projectId: int.parse(selectedProjectId!),
        transcript: transcript.trim(),
        summary: summary.trim(),
        functionalRequirements: _textToList(functionalRequirements),
        nonFunctionalRequirements: _textToList(nonFunctionalRequirements),
        tasks: _textToList(detectedTasks),
        audioFileName: audioPath?.split('/').last,
      );

      if (!mounted) return;

      setState(() {
        savedToBackend = true;
        successMessage =
            'Resultado de reunión guardado correctamente en el backend.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        successMessage =
            'El resultado quedó listo en la app, pero el backend todavía no confirmó guardado real.';
      });
    }
  }

  void resetMeeting() {
    _timer?.cancel();

    setState(() {
      state = MeetingModeState.idle;
      audioPath = null;
      recordingDuration = Duration.zero;
      transcript = '';
      summary = '';
      functionalRequirements = '';
      nonFunctionalRequirements = '';
      detectedTasks = '';
      errorMessage = null;
      successMessage = null;
      processingInfo = null;
      savedToBackend = false;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Color _statusColor() {
    switch (state) {
      case MeetingModeState.recording:
        return Colors.redAccent;
      case MeetingModeState.processing:
        return Colors.orangeAccent;
      case MeetingModeState.ready:
        return Colors.greenAccent;
      case MeetingModeState.idle:
        return _pink;
    }
  }

  String _statusText() {
    switch (state) {
      case MeetingModeState.recording:
        return 'Grabando reunión...';
      case MeetingModeState.processing:
        return 'Procesando reunión...';
      case MeetingModeState.ready:
        return savedToBackend ? 'Resultado guardado' : 'Resultado listo';
      case MeetingModeState.idle:
        return 'Listo para iniciar';
    }
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _statusColor(),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _statusColor().withOpacity(0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (state == MeetingModeState.recording)
                Text(
                  _formatDuration(recordingDuration),
                  style: const TextStyle(
                    color: _pink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
            ],
          ),
          if (processingInfo != null && processingInfo!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                processingInfo!,
                style: const TextStyle(color: _textGrey, height: 1.45),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectSelector() {
    if (loadingProjects) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(color: _pink),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedProjectId,
          dropdownColor: const Color(0xFF1B1E28),
          isExpanded: true,
          iconEnabledColor: Colors.white,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          items: projects.map((project) {
            final id = project['id'].toString();
            final name = (project['name'] ?? 'Proyecto').toString();
            return DropdownMenuItem<String>(value: id, child: Text(name));
          }).toList(),
          onChanged:
              state == MeetingModeState.recording ||
                  state == MeetingModeState.processing
              ? null
              : (value) {
                  setState(() {
                    selectedProjectId = value;
                  });
                },
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (state == MeetingModeState.idle) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: startRecording,
          icon: const Icon(Icons.mic_rounded),
          label: const Text('Iniciar grabación'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _pink,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      );
    }

    if (state == MeetingModeState.recording) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: stopRecording,
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Detener grabación'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      );
    }

    if (state == MeetingModeState.processing) {
      return const SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Procesando...'),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: resetMeeting,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: _borderColor),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              'Nueva reunión',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: saveMeetingResult,
            style: ElevatedButton.styleFrom(
              backgroundColor: _pink,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              'Guardar resultado',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableArea({
    required String title,
    required String value,
    required ValueChanged<String> onChanged,
    int minLines = 3,
    int maxLines = 6,
  }) {
    final controller = TextEditingController(text: value);
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          minLines: minLines,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1E2030),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainAppShell(
      selectedItem: null,
      eyebrow: 'Exclusivo móvil',
      titleWhite: 'Modo Reunión ',
      titlePink: 'inteligente',
      description:
          'Graba reuniones desde tu celular y prepara contenido útil para tu SRS.',
      showTopNav: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(),
          const SizedBox(height: 18),
          const Text(
            'Proyecto destino',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _buildProjectSelector(),
          const SizedBox(height: 18),
          _buildActionButtons(),
          if (audioPath != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Audio capturado',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    audioPath!.split('/').last,
                    style: const TextStyle(color: _textGrey, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 18),
            _MessageBanner(text: errorMessage!, success: false),
          ],
          if (successMessage != null) ...[
            const SizedBox(height: 18),
            _MessageBanner(text: successMessage!, success: true),
          ],
          if (state == MeetingModeState.ready) ...[
            const SizedBox(height: 22),
            _buildEditableArea(
              title: 'Transcripción',
              value: transcript,
              onChanged: (value) {
                transcript = value;
              },
              minLines: 5,
              maxLines: 10,
            ),
            const SizedBox(height: 18),
            _buildEditableArea(
              title: 'Resumen',
              value: summary,
              onChanged: (value) {
                summary = value;
              },
              minLines: 3,
              maxLines: 6,
            ),
            const SizedBox(height: 18),
            _buildEditableArea(
              title: 'Requerimientos funcionales sugeridos',
              value: functionalRequirements,
              onChanged: (value) {
                functionalRequirements = value;
              },
              minLines: 4,
              maxLines: 8,
            ),
            const SizedBox(height: 18),
            _buildEditableArea(
              title: 'Requerimientos no funcionales sugeridos',
              value: nonFunctionalRequirements,
              onChanged: (value) {
                nonFunctionalRequirements = value;
              },
              minLines: 4,
              maxLines: 8,
            ),
            const SizedBox(height: 18),
            _buildEditableArea(
              title: 'Tareas detectadas',
              value: detectedTasks,
              onChanged: (value) {
                detectedTasks = value;
              },
              minLines: 4,
              maxLines: 8,
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final String text;
  final bool success;

  const _MessageBanner({required this.text, required this.success});

  @override
  Widget build(BuildContext context) {
    final bg = success ? const Color(0x221BC47D) : const Color(0x22E8365D);
    final fg = success ? const Color(0xFF1BC47D) : _pink;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(
            success
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            color: fg,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
