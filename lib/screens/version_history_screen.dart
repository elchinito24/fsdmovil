import 'package:flutter/material.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';
import 'package:fsdmovil/services/api_service.dart';

const _pink = Color(0xFFE8365D);
const _cardBg = Color(0xFF191B24);
const _borderColor = Color(0xFF2A2D3A);
const _textGrey = Color(0xFF8E8E93);

class VersionHistoryScreen extends StatefulWidget {
  final int projectId;

  const VersionHistoryScreen({super.key, required this.projectId});

  @override
  State<VersionHistoryScreen> createState() => _VersionHistoryScreenState();
}

class _VersionHistoryScreenState extends State<VersionHistoryScreen> {
  List<dynamic> history = [];
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      final data = await ApiService.getProjectHistory(widget.projectId);

      if (!mounted) return;

      setState(() {
        history = data;
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

  @override
  Widget build(BuildContext context) {
    return MainAppShell(
      selectedItem: null,
      eyebrow: '',
      titleWhite: 'Historial ',
      titlePink: 'de versiones',
      description: 'Sigue todos los cambios realizados en tu documento SRS.',
      child: loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 60),
                child: CircularProgressIndicator(color: _pink),
              ),
            )
          : errorMessage != null
          ? Center(
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.white),
              ),
            )
          : history.isEmpty
          ? const Center(
              child: Text(
                'No hay historial aún',
                style: TextStyle(color: Colors.white),
              ),
            )
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];

                final data = {
                  "version": "v${history.length - index}",
                  "current": index == 0,
                  "title": item["summary"] ?? "Sin resumen",
                  "author": item["created_by"] ?? "Usuario",
                  "date": _formatDate(item["created_at"]),
                  "changes": [item["summary"] ?? "Sin cambios registrados"],
                };

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _VersionCard(data: data),
                );
              },
            ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  final Map data;

  const _VersionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isCurrent = data["current"] == true;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                data["version"],
                style: const TextStyle(
                  color: _pink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x221BC47D),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    "Actual",
                    style: TextStyle(
                      color: Color(0xFF1BC47D),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data["title"],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${data["author"]} • ${data["date"]}",
            style: const TextStyle(color: _textGrey),
          ),
          const SizedBox(height: 14),
          ...List.generate(
            (data["changes"] as List).length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.arrow_right, color: Colors.green),
                  Expanded(
                    child: Text(
                      data["changes"][i],
                      style: const TextStyle(color: _textGrey),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: _pink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text("Ver detalles"),
          ),
        ],
      ),
    );
  }
}
