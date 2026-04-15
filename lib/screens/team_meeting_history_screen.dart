import 'package:flutter/material.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';

const _pink = Color(0xFFE8365D);
const _cardBg = Color(0xFF191B24);
const _borderColor = Color(0xFF2A2D3A);
const _textGrey = Color(0xFF8E8E93);

class TeamMeetingHistoryScreen extends StatefulWidget {
  final int projectId;

  const TeamMeetingHistoryScreen({super.key, required this.projectId});

  @override
  State<TeamMeetingHistoryScreen> createState() =>
      _TeamMeetingHistoryScreenState();
}

class _TeamMeetingHistoryScreenState extends State<TeamMeetingHistoryScreen> {
  bool loading = true;
  String? errorMessage;
  String projectName = '';
  List<dynamic> meetings = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await ApiService.getTeamMeetingProjectHistory(
        widget.projectId,
      );

      if (!mounted) return;

      setState(() {
        projectName = (data['project_name'] ?? '').toString();
        meetings = List<dynamic>.from(data['results'] ?? []);
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

  String _formatDate(dynamic raw) {
    final value = raw?.toString();
    if (value == null || value.isEmpty) return 'Sin fecha';

    try {
      final date = DateTime.parse(value).toLocal();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year • $hour:$minute';
    } catch (_) {
      return value;
    }
  }

  List<String> _requirementDescriptions(dynamic value) {
    if (value is! List) return [];

    return value
        .map((item) {
          if (item is Map) {
            final title = (item['title'] ?? '').toString().trim();
            final description = (item['description'] ?? '').toString().trim();

            if (title.isNotEmpty && description.isNotEmpty) {
              return '$title: $description';
            }
            if (description.isNotEmpty) return description;
            if (title.isNotEmpty) return title;
          }

          return item.toString().trim();
        })
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _participantNames(dynamic participants) {
    if (participants is! List || participants.isEmpty) {
      return 'Sin participantes registrados';
    }

    final names = participants
        .map((p) {
          if (p is Map) {
            final first = (p['first_name'] ?? '').toString().trim();
            final last = (p['last_name'] ?? '').toString().trim();
            final email = (p['email'] ?? '').toString().trim();
            final full = '$first $last'.trim();
            return full.isNotEmpty ? full : email;
          }
          return p.toString();
        })
        .where((e) => e.toString().trim().isNotEmpty)
        .toList();

    return names.isEmpty ? 'Sin participantes registrados' : names.join(', ');
  }

  Widget _buildRequirementList(String title, List<String> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
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
            const Text('Sin información', style: TextStyle(color: _textGrey))
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.circle, size: 8, color: _pink),
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

  Widget _buildMeetingCard(Map<String, dynamic> item) {
    final summary = (item['summary'] ?? '').toString().trim();
    final functional = _requirementDescriptions(
      item['functional_requirements'],
    );
    final nonFunctional = _requirementDescriptions(
      item['non_functional_requirements'],
    );
    final participants = _participantNames(item['participants']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (item['title'] ?? 'Llamada sin título').toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                icon: Icons.schedule_rounded,
                label: _formatDate(item['started_at']),
              ),
              _InfoChip(
                icon: Icons.timer_outlined,
                label: (item['duration_label'] ?? 'Sin duración').toString(),
              ),
              _InfoChip(
                icon: Icons.person_rounded,
                label: (item['host_email'] ?? 'Sin host').toString(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Participantes',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            participants,
            style: const TextStyle(color: _textGrey, height: 1.45),
          ),
          const SizedBox(height: 14),
          const Text(
            'Resumen',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            summary.isEmpty ? 'Sin resumen.' : summary,
            style: const TextStyle(color: _textGrey, height: 1.45),
          ),
          const SizedBox(height: 14),
          _buildRequirementList('Requerimientos funcionales', functional),
          const SizedBox(height: 12),
          _buildRequirementList('Requerimientos no funcionales', nonFunctional),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: CircularProgressIndicator(color: _pink),
        ),
      );
    }

    if (errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _borderColor),
        ),
        child: Text(
          errorMessage!,
          style: const TextStyle(color: _pink, fontWeight: FontWeight.w700),
        ),
      );
    }

    if (meetings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _borderColor),
        ),
        child: const Text(
          'Aún no hay llamadas registradas para este proyecto.',
          style: TextStyle(color: _textGrey),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: meetings
            .map(
              (meeting) =>
                  _buildMeetingCard(Map<String, dynamic>.from(meeting as Map)),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainAppShell(
      selectedItem: null,
      eyebrow: 'Historial de reuniones',
      titleWhite: 'Llamadas del ',
      titlePink: 'proyecto',
      description: projectName.isEmpty
          ? 'Consulta el historial de llamadas grupales procesadas.'
          : 'Consulta las llamadas grupales registradas en $projectName.',
      showTopNav: false,
      child: _buildBody(),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x22E8365D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x55E8365D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _pink),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _pink,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
