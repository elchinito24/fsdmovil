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
  bool _endingMeeting = false;

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
    if (_endingMeeting) return;

    setState(() {
      _endingMeeting = true;
    });

    try {
      await ApiService.endTeamMeeting(widget.sessionId);

      if (!mounted) return;

      await _leaveRoom();

      if (!mounted) return;

      if (isHost) {
        context.go('/team-meeting-result/${widget.sessionId}');
      } else {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al finalizar reunión: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: _pink,
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _endingMeeting = false;
      });
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
                            onPressed: _endingMeeting ? null : _endMeeting,
                            icon: _endingMeeting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.stop_circle_outlined),
                            label: Text(
                              _endingMeeting
                                  ? 'Finalizando...'
                                  : 'Finalizar reunión',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
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
    final project = Map<String, dynamic>.from(
      data['project'] ?? <String, dynamic>{},
    );
    final session = Map<String, dynamic>.from(
      data['session'] ?? <String, dynamic>{},
    );
    final preview = Map<String, dynamic>.from(
      data['srs_preview'] ?? <String, dynamic>{},
    );

    final functional = _stringList(preview['functional_requirements']);
    final nonFunctional = _stringList(preview['non_functional_requirements']);

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
                    (project['name'] ?? 'Documento SRS').toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${project['code'] ?? ''} • ${(session['title'] ?? '').toString()}',
                    style: const TextStyle(color: _textGrey, height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  _PreviewListBlock(
                    title: 'Requerimientos funcionales',
                    items: functional,
                  ),
                  const SizedBox(height: 14),
                  _PreviewListBlock(
                    title: 'Requerimientos no funcionales',
                    items: nonFunctional,
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

class _PreviewListBlock extends StatelessWidget {
  final String title;
  final List<String> items;

  const _PreviewListBlock({required this.title, required this.items});

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
            const Text('Sin datos.', style: TextStyle(color: _textGrey))
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• $item',
                  style: const TextStyle(color: _textGrey, height: 1.45),
                ),
              ),
            ),
        ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0x22E8365D),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: _pink, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (isLocal)
            const Text(
              'Tú',
              style: TextStyle(color: _pink, fontWeight: FontWeight.w800),
            ),
        ],
      ),
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

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return _Card(
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
