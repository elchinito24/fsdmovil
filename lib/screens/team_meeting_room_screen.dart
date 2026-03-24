import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';

const _pink = Color(0xFFE8365D);
const _cardBg = Color(0xFF191B24);
const _borderColor = Color(0xFF2A2D3A);
const _textGrey = Color(0xFF8E8E93);

class TeamMeetingRoomScreen extends StatefulWidget {
  final int sessionId;

  const TeamMeetingRoomScreen({super.key, required this.sessionId});

  @override
  State<TeamMeetingRoomScreen> createState() => _TeamMeetingRoomScreenState();
}

class _TeamMeetingRoomScreenState extends State<TeamMeetingRoomScreen> {
  Room? room;
  bool connecting = true;
  bool micEnabled = true;
  bool isHost = false;
  bool loadingPreview = false;
  String title = 'Reunión de equipo';
  String subtitle = '';
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _connectRoom();
  }

  @override
  void dispose() {
    _leaveRoom();
    super.dispose();
  }

  Future<void> _connectRoom() async {
    try {
      final detail = await ApiService.getTeamMeetingDetail(widget.sessionId);
      final tokenData = await ApiService.getTeamMeetingJoinToken(
        widget.sessionId,
      );

      final wsUrl = (tokenData['ws_url'] ?? '').toString().trim();
      final token = (tokenData['token'] ?? '').toString().trim();

      if (wsUrl.isEmpty || token.isEmpty) {
        throw Exception('No se recibió ws_url o token válido.');
      }

      final liveRoom = Room();

      await liveRoom.connect(
        wsUrl,
        token,
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );

      await liveRoom.localParticipant?.setMicrophoneEnabled(true);
      await ApiService.connectTeamMeetingParticipant(widget.sessionId);

      if (!mounted) return;

      setState(() {
        room = liveRoom;
        isHost = tokenData['is_host'] == true;
        title = (detail['title'] ?? 'Reunión de equipo').toString();
        subtitle =
            '${detail['project_name'] ?? ''} • ${detail['workspace_name'] ?? ''}';
        connecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        connecting = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _toggleMic() async {
    if (room == null) return;

    final nextState = !micEnabled;
    await room!.localParticipant?.setMicrophoneEnabled(nextState);

    if (!mounted) return;
    setState(() {
      micEnabled = nextState;
    });
  }

  Future<void> _leaveRoom() async {
    try {
      await ApiService.disconnectTeamMeetingParticipant(widget.sessionId);
    } catch (_) {}

    try {
      await room?.disconnect();
    } catch (_) {}
  }

  Future<void> _endMeeting() async {
    try {
      await ApiService.endTeamMeeting(widget.sessionId);
      if (!mounted) return;
      await _leaveRoom();
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: _pink,
        ),
      );
    }
  }

  Future<void> _openDocumentPreview() async {
    setState(() {
      loadingPreview = true;
    });

    try {
      final data = await ApiService.getTeamMeetingDocumentPreview(
        widget.sessionId,
      );

      if (!mounted) return;

      setState(() {
        loadingPreview = false;
      });

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _DocumentPreviewSheet(data: data),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadingPreview = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: _pink,
        ),
      );
    }
  }

  List<Participant> _participants() {
    if (room == null) return [];
    return [
      if (room!.localParticipant != null) room!.localParticipant!,
      ...room!.remoteParticipants.values,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final participants = _participants();

    return MainAppShell(
      selectedItem: null,
      eyebrow: 'LiveKit room',
      titleWhite: 'Llamada de ',
      titlePink: 'equipo',
      description: 'Participa en la reunión de audio del proyecto.',
      showTopNav: false,
      child: connecting
          ? const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 80),
                child: CircularProgressIndicator(color: _pink),
              ),
            )
          : errorMessage != null
          ? _ErrorState(message: errorMessage!)
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Card(
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
                          subtitle,
                          style: const TextStyle(
                            color: _textGrey,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _StatusChip(
                              text:
                                  room?.connectionState.toString() ??
                                  'desconocido',
                            ),
                            _StatusChip(
                              text: 'Participantes: ${participants.length}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: loadingPreview
                              ? null
                              : _openDocumentPreview,
                          icon: const Icon(Icons.visibility_outlined),
                          label: Text(
                            loadingPreview
                                ? 'Cargando documento...'
                                : 'Vista previa del documento',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF232736),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Participantes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (participants.isEmpty)
                    const _Card(
                      child: Text(
                        'Aún no hay participantes visibles en la sala.',
                        style: TextStyle(color: _textGrey),
                      ),
                    )
                  else
                    ...participants.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ParticipantCard(
                          name: p.name?.isNotEmpty == true
                              ? p.name!
                              : p.identity,
                          isLocal: p is LocalParticipant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _toggleMic,
                          icon: Icon(
                            micEnabled
                                ? Icons.mic_rounded
                                : Icons.mic_off_rounded,
                          ),
                          label: Text(
                            micEnabled ? 'Silenciar' : 'Activar micrófono',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF232736),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _leaveRoom();
                            if (!mounted) return;
                            context.pop();
                          },
                          icon: const Icon(Icons.call_end_rounded),
                          label: const Text(
                            'Salir',
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
                      if (isHost) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _endMeeting,
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text(
                              'Finalizar',
                              style: TextStyle(fontWeight: FontWeight.w800),
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
                      ],
                    ],
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

class _ParticipantCard extends StatelessWidget {
  final String name;
  final bool isLocal;

  const _ParticipantCard({required this.name, required this.isLocal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x22E8365D),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_rounded, color: _pink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isLocal ? '$name (tú)' : name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

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
      child: Text(
        message,
        style: const TextStyle(
          color: _pink,
          fontWeight: FontWeight.w700,
          height: 1.45,
        ),
      ),
    );
  }
}

class _DocumentPreviewSheet extends StatelessWidget {
  final Map<String, dynamic> data;

  const _DocumentPreviewSheet({required this.data});

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final preview = Map<String, dynamic>.from(
      data['document_preview'] ?? <String, dynamic>{},
    );

    final functional = _stringList(preview['functional_requirements']);
    final nonFunctional = _stringList(preview['non_functional_requirements']);
    final meetingTasks = _stringList(preview['meeting_tasks']);
    final productFunctions = _stringList(preview['product_functions']);
    final userClasses = _stringList(preview['user_classes']);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF10121A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (data['project_name'] ?? 'Documento SRS').toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${data['project_code'] ?? ''} • ${data['workspace_name'] ?? ''}',
                    style: const TextStyle(color: _textGrey, height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  _PreviewBlock(
                    title: 'Propósito',
                    body: (preview['purpose'] ?? '').toString(),
                  ),
                  const SizedBox(height: 14),
                  _PreviewBlock(
                    title: 'Alcance',
                    body: (preview['scope'] ?? '').toString(),
                  ),
                  const SizedBox(height: 14),
                  _PreviewBlock(
                    title: 'Perspectiva del producto',
                    body: (preview['product_perspective'] ?? '').toString(),
                  ),
                  const SizedBox(height: 14),
                  _PreviewListBlock(
                    title: 'Funciones del producto',
                    items: productFunctions,
                  ),
                  const SizedBox(height: 14),
                  _PreviewListBlock(
                    title: 'Clases de usuario',
                    items: userClasses,
                  ),
                  const SizedBox(height: 14),
                  _PreviewListBlock(
                    title: 'Requerimientos funcionales',
                    items: functional,
                  ),
                  const SizedBox(height: 14),
                  _PreviewListBlock(
                    title: 'Requerimientos no funcionales',
                    items: nonFunctional,
                  ),
                  const SizedBox(height: 14),
                  _PreviewListBlock(
                    title: 'Tareas registradas',
                    items: meetingTasks,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewBlock extends StatelessWidget {
  final String title;
  final String body;

  const _PreviewBlock({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body.trim().isEmpty ? 'Sin información disponible.' : body,
            style: const TextStyle(color: _textGrey, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _PreviewListBlock extends StatelessWidget {
  final String title;
  final List<String> items;

  const _PreviewListBlock({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text(
              'Sin elementos disponibles.',
              style: TextStyle(color: _textGrey, height: 1.45),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, color: _pink, size: 8),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(color: _textGrey, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
