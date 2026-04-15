import 'package:flutter/material.dart';
import 'package:fsdmovil/models/task.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _loadingProjects = true;
  bool _loadingTasks = false;
  String? _error;
  List<dynamic> _projects = [];
  int? _selectedProjectId;
  List<Task> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loadingProjects = true;
      _error = null;
    });
    try {
      final data = await ApiService.getProjects();
      if (!mounted) return;
      setState(() {
        _projects = data;
        _loadingProjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProjects = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadTasks(int projectId) async {
    setState(() {
      _loadingTasks = true;
      _error = null;
      _tasks = [];
    });
    try {
      final data = await ApiService.getTasks(projectId);
      if (!mounted) return;
      final tasks = data
          .map((d) => Task.fromJson(d as Map<String, dynamic>))
          .where((t) => t.startDate != null && t.endDate != null)
          .toList()
        ..sort((a, b) => a.startDate!.compareTo(b.startDate!));
      setState(() {
        _tasks = tasks;
        _loadingTasks = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingTasks = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainAppShell(
      insideShell: true,
      selectedItem: TopNavItem.schedule,
      eyebrow: 'Cronograma',
      titleWhite: 'Cronograma ',
      titlePink: 'de actividades',
      description:
          'Visualiza el avance y las fechas de cada tarea del proyecto en un diagrama de Gantt.',
      onRefresh: _selectedProjectId != null
          ? () => _loadTasks(_selectedProjectId!)
          : _loadProjects,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadingProjects) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: fsdPink)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Project selector ─────────────────────────────────────────────
        _ProjectSelector(
          projects: _projects,
          selectedId: _selectedProjectId,
          onSelect: (id) {
            setState(() => _selectedProjectId = id);
            _loadTasks(id);
          },
        ),
        const SizedBox(height: 24),

        // ── Content area ─────────────────────────────────────────────────
        if (_selectedProjectId == null)
          _EmptyProjectState()
        else if (_loadingTasks)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator(color: fsdPink)),
          )
        else if (_error != null)
          _ErrorState(
            message: _error!,
            onRetry: () => _loadTasks(_selectedProjectId!),
          )
        else if (_tasks.isEmpty)
          const _EmptyTasksState()
        else
          _GanttView(tasks: _tasks),
      ],
    );
  }
}

// ─── Project selector ─────────────────────────────────────────────────────────

class _ProjectSelector extends StatelessWidget {
  final List<dynamic> projects;
  final int? selectedId;
  final void Function(int) onSelect;

  const _ProjectSelector({
    required this.projects,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);

    if (projects.isEmpty) {
      return Text(
        'No hay proyectos disponibles.',
        style: const TextStyle(color: fsdTextGrey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PROYECTO',
          style: TextStyle(
            color: fsdPink,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: projects.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final p = projects[i];
              final id = (p['id'] as num).toInt();
              final name = (p['name'] ?? p['code'] ?? 'Proyecto').toString();
              final isSelected = id == selectedId;

              return GestureDetector(
                onTap: () => onSelect(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? fsdPink : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? fsdPink : borderColor,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: fsdPink.withOpacity(0.25),
                              blurRadius: 10,
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : fsdTextGrey,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Gantt view (wrapper) ─────────────────────────────────────────────────────

class _GanttView extends StatelessWidget {
  final List<Task> tasks;

  const _GanttView({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Compute date range
    DateTime minDate = tasks
        .map((t) => t.startDate!)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    DateTime maxDate = tasks
        .map((t) => t.endDate!)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    // Normalize to day boundaries and add padding
    minDate = DateTime(minDate.year, minDate.month, minDate.day)
        .subtract(const Duration(days: 3));
    maxDate = DateTime(maxDate.year, maxDate.month, maxDate.day)
        .add(const Duration(days: 3));

    final totalDays = maxDate.difference(minDate).inDays + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Legend ───────────────────────────────────────────────────────
        _StatusLegend(isDark: isDark),
        const SizedBox(height: 16),
        // ── Gantt chart ──────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? fsdCardBg : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? fsdBorderColor : const Color(0xFFE5E7EF),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _GanttChart(
                tasks: tasks,
                minDate: minDate,
                maxDate: maxDate,
                totalDays: totalDays,
                isDark: isDark,
              ),
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ─── Status legend ────────────────────────────────────────────────────────────

class _StatusLegend extends StatelessWidget {
  final bool isDark;

  const _StatusLegend({required this.isDark});

  static const _items = [
    _LegendItem('Por hacer', Color(0xFFF2A91D)),
    _LegendItem('En progreso', Color(0xFF55A6FF)),
    _LegendItem('Completado', Color(0xFF1BC47D)),
    _LegendItem('Cancelado', Color(0xFF8E8E93)),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: _items
          .map(
            (item) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  item.label,
                  style: const TextStyle(
                    color: fsdTextGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _LegendItem {
  final String label;
  final Color color;
  const _LegendItem(this.label, this.color);
}

// ─── Gantt chart ──────────────────────────────────────────────────────────────

class _GanttChart extends StatelessWidget {
  final List<Task> tasks;
  final DateTime minDate;
  final DateTime maxDate;
  final int totalDays;
  final bool isDark;

  static const double _nameWidth = 130.0;
  static const double _dayWidth = 36.0;
  static const double _rowHeight = 54.0;
  static const double _barHeight = 26.0;
  static const double _monthHeaderH = 24.0;
  static const double _dayHeaderH = 28.0;

  const _GanttChart({
    required this.tasks,
    required this.minDate,
    required this.maxDate,
    required this.totalDays,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final todayOffset = todayNorm.difference(minDate).inDays;

    final dates = List.generate(
      totalDays,
      (i) => minDate.add(Duration(days: i)),
    );
    final monthGroups = _buildMonthGroups(dates);

    final borderColor = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);
    final headerBg = isDark ? const Color(0xFF252838) : const Color(0xFFF6F7FB);
    final nameBg = isDark ? const Color(0xFF252838) : const Color(0xFFF6F7FB);
    final titleColor = isDark ? Colors.white : const Color(0xFF151823);

    return SizedBox(
      width: _nameWidth + _dayWidth * totalDays,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Month header ───────────────────────────────────────────────
          Container(
            height: _monthHeaderH,
            color: headerBg,
            child: Row(
              children: [
                SizedBox(width: _nameWidth),
                ...monthGroups.map(
                  (mg) => SizedBox(
                    width: _dayWidth * mg.days,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        mg.label,
                        style: const TextStyle(
                          color: fsdPink,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Day header ─────────────────────────────────────────────────
          Container(
            height: _dayHeaderH,
            decoration: BoxDecoration(
              color: headerBg,
              border: Border(
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: Row(
              children: [
                // "TAREA" label in the name column
                Container(
                  width: _nameWidth,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'TAREA',
                    style: const TextStyle(
                      color: fsdTextGrey,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                ...dates.map((d) {
                  final isToday = d.year == today.year &&
                      d.month == today.month &&
                      d.day == today.day;
                  final isWeekend = d.weekday == DateTime.saturday ||
                      d.weekday == DateTime.sunday;
                  return SizedBox(
                    width: _dayWidth,
                    child: Center(
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: isToday
                            ? BoxDecoration(
                                color: fsdPink,
                                borderRadius: BorderRadius.circular(6),
                              )
                            : null,
                        child: Center(
                          child: Text(
                            '${d.day}',
                            style: TextStyle(
                              color: isToday
                                  ? Colors.white
                                  : (isWeekend
                                      ? fsdPink.withOpacity(0.6)
                                      : fsdTextGrey),
                              fontSize: 10,
                              fontWeight: isToday
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // ── Task rows ──────────────────────────────────────────────────
          ...tasks.asMap().entries.map((entry) {
            final i = entry.key;
            final task = entry.value;
            final isLast = i == tasks.length - 1;

            final start = DateTime(
              task.startDate!.year,
              task.startDate!.month,
              task.startDate!.day,
            );
            final end = DateTime(
              task.endDate!.year,
              task.endDate!.month,
              task.endDate!.day,
            );

            final startOffset =
                start.difference(minDate).inDays.clamp(0, totalDays);
            final endOffset =
                end.difference(minDate).inDays.clamp(0, totalDays - 1);
            final barDays = (endOffset - startOffset + 1).clamp(1, totalDays);
            final barLeft = _dayWidth * startOffset;
            final barWidth = (_dayWidth * barDays).clamp(
              _dayWidth * 0.5,
              _dayWidth * totalDays.toDouble(),
            );

            final taskColor = task.taskColor;
            final rowBg = isDark
                ? (i.isEven ? fsdCardBg : const Color(0xFF262830))
                : (i.isEven ? Colors.white : const Color(0xFFFAFAFC));

            return GestureDetector(
              onTap: () => _showDetail(context, task),
              child: Container(
                height: _rowHeight,
                decoration: BoxDecoration(
                  color: rowBg,
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(color: borderColor, width: 0.5),
                        ),
                ),
                child: Row(
                  children: [
                    // Name column
                    Container(
                      width: _nameWidth,
                      height: _rowHeight,
                      color: nameBg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: task.statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              task.statusLabel,
                              style: TextStyle(
                                color: task.statusColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Timeline column
                    SizedBox(
                      width: _dayWidth * totalDays,
                      height: _rowHeight,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          // Weekend column shading
                          ...List.generate(totalDays, (di) {
                            final d = minDate.add(Duration(days: di));
                            final isWe = d.weekday == DateTime.saturday ||
                                d.weekday == DateTime.sunday;
                            if (!isWe) return const SizedBox.shrink();
                            return Positioned(
                              left: _dayWidth * di,
                              top: 0,
                              bottom: 0,
                              width: _dayWidth,
                              child: Container(
                                color: isDark
                                    ? Colors.white.withOpacity(0.03)
                                    : Colors.black.withOpacity(0.02),
                              ),
                            );
                          }),
                          // Today line
                          if (todayOffset >= 0 && todayOffset < totalDays)
                            Positioned(
                              left: _dayWidth * todayOffset +
                                  _dayWidth / 2 -
                                  0.5,
                              top: 0,
                              bottom: 0,
                              width: 1,
                              child: Container(
                                color: fsdPink.withOpacity(0.35),
                              ),
                            ),
                          // Task bar
                          Positioned(
                            left: barLeft,
                            top: (_rowHeight - _barHeight) / 2,
                            child: GestureDetector(
                              onTap: () => _showDetail(context, task),
                              child: Container(
                                width: barWidth,
                                height: _barHeight,
                                decoration: BoxDecoration(
                                  color: taskColor.withOpacity(0.88),
                                  borderRadius: BorderRadius.circular(7),
                                  boxShadow: [
                                    BoxShadow(
                                      color: taskColor.withOpacity(0.28),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 7),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  task.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TaskDetailSheet(task: task, isDark: isDark),
    );
  }

  List<_MonthGroup> _buildMonthGroups(List<DateTime> dates) {
    final result = <_MonthGroup>[];
    if (dates.isEmpty) return result;

    var curMonth = dates.first.month;
    var curYear = dates.first.year;
    var count = 0;

    for (final d in dates) {
      if (d.month == curMonth && d.year == curYear) {
        count++;
      } else {
        result.add(_MonthGroup(_monthLabel(curMonth, curYear), count));
        curMonth = d.month;
        curYear = d.year;
        count = 1;
      }
    }
    result.add(_MonthGroup(_monthLabel(curMonth, curYear), count));
    return result;
  }

  String _monthLabel(int month, int year) {
    const m = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
    ];
    return '${m[month - 1]} $year';
  }
}

class _MonthGroup {
  final String label;
  final int days;
  const _MonthGroup(this.label, this.days);
}

// ─── Task detail bottom sheet ─────────────────────────────────────────────────

class _TaskDetailSheet extends StatelessWidget {
  final Task task;
  final bool isDark;

  const _TaskDetailSheet({required this.task, required this.isDark});

  String _formatDate(DateTime? d) {
    if (d == null) return '-';
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E2130) : Colors.white;
    final border = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);
    final titleColor = isDark ? Colors.white : const Color(0xFF151823);
    final subColor = isDark ? fsdTextGrey : const Color(0xFF6B7280);

    final duration = task.startDate != null && task.endDate != null
        ? task.endDate!.difference(task.startDate!).inDays + 1
        : null;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 30,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Color bar + title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12, top: 2),
                  decoration: BoxDecoration(
                    color: task.taskColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: subColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Status + priority row
            Row(
              children: [
                _InfoPill(
                  label: task.statusLabel,
                  color: task.statusColor,
                ),
                const SizedBox(width: 8),
                _InfoPill(
                  label: 'Prioridad: ${task.priorityLabel}',
                  color: task.priorityColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Dates grid
            Row(
              children: [
                Expanded(
                  child: _DateCard(
                    label: 'INICIO',
                    value: _formatDate(task.startDate),
                    icon: Icons.play_circle_outline_rounded,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateCard(
                    label: 'FIN',
                    value: _formatDate(task.endDate),
                    icon: Icons.stop_circle_outlined,
                    isDark: isDark,
                  ),
                ),
                if (duration != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateCard(
                      label: 'DURACIÓN',
                      value: '$duration días',
                      icon: Icons.timelapse_rounded,
                      isDark: isDark,
                    ),
                  ),
                ],
              ],
            ),
            // Assignee
            if (task.assigneeName.isNotEmpty || task.assigneeEmail.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: fsdPink,
                    child: Text(
                      (task.assigneeName.isNotEmpty
                              ? task.assigneeName[0]
                              : task.assigneeEmail.isNotEmpty
                                  ? task.assigneeEmail[0]
                                  : '?')
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (task.assigneeName.isNotEmpty)
                        Text(
                          task.assigneeName,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (task.assigneeEmail.isNotEmpty)
                        Text(
                          task.assigneeEmail,
                          style: TextStyle(
                            color: subColor,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
            // Description
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(color: border, height: 1),
              const SizedBox(height: 12),
              Text(
                task.description,
                style: TextStyle(
                  color: subColor,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  const _DateCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF252838) : const Color(0xFFF6F7FB);
    final border = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);
    final titleColor = isDark ? Colors.white : const Color(0xFF151823);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fsdTextGrey, size: 12),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: fsdTextGrey,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: titleColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty / error states ─────────────────────────────────────────────────────

class _EmptyProjectState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: fsdPink.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                size: 34,
                color: fsdPink,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Selecciona un proyecto',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Elige un proyecto arriba para ver\nsu cronograma de actividades.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fsdTextGrey,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTasksState extends StatelessWidget {
  const _EmptyTasksState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 52,
              color: fsdTextGrey.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin tareas con fechas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Este proyecto no tiene tareas\ncon fechas de inicio y fin definidas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: fsdTextGrey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: fsdPink),
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
                  borderRadius: BorderRadius.circular(14),
                ),
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
