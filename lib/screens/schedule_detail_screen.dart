import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/models/task.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';

// ─── View mode ────────────────────────────────────────────────────────────────

enum _ViewMode { day, week, month }

// ─── Screen ──────────────────────────────────────────────────────────────────

class ScheduleDetailScreen extends StatefulWidget {
  final int projectId;
  final String? projectName;
  final String? projectCode;

  const ScheduleDetailScreen({
    super.key,
    required this.projectId,
    this.projectName,
    this.projectCode,
  });

  @override
  State<ScheduleDetailScreen> createState() => _ScheduleDetailScreenState();
}

class _ScheduleDetailScreenState extends State<ScheduleDetailScreen> {
  bool _loading = true;
  String? _error;
  List<Task> _tasks = [];
  _ViewMode _viewMode = _ViewMode.month;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getTasks(widget.projectId);
      if (!mounted) return;
      final tasks = data
          .map((d) => Task.fromJson(d as Map<String, dynamic>))
          .where((t) => t.startDate != null && t.endDate != null)
          .toList()
        ..sort((a, b) => a.startDate!.compareTo(b.startDate!));
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF151823) : const Color(0xFFF6F7FB);
    final titleColor = isDark ? Colors.white : const Color(0xFF151823);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ───────────────────────────────────────────────────
            _TopBar(
              projectCode: widget.projectCode,
              projectName: widget.projectName,
              viewMode: _viewMode,
              onViewModeChanged: (m) => setState(() => _viewMode = m),
              onBack: () => context.pop(),
              isDark: isDark,
            ),
            // ── Title ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Cronograma ',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const TextSpan(
                      text: 'de Actividades',
                      style: TextStyle(
                        color: fsdPink,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: _buildContent(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: fsdPink));
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _loadTasks);
    }
    if (_tasks.isEmpty) {
      return const _EmptyTasksState();
    }
    return _GanttView(tasks: _tasks, viewMode: _viewMode, isDark: isDark);
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String? projectCode;
  final String? projectName;
  final _ViewMode viewMode;
  final ValueChanged<_ViewMode> onViewModeChanged;
  final VoidCallback onBack;
  final bool isDark;

  const _TopBar({
    required this.projectCode,
    required this.projectName,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.onBack,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);
    final subColor = isDark ? fsdTextGrey : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: onBack,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_rounded, color: fsdPink, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Volver',
                  style: const TextStyle(
                    color: fsdPink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // View mode buttons
          _ViewToggle(
            viewMode: viewMode,
            onChanged: onViewModeChanged,
            isDark: isDark,
          ),
          // Project info
          if (projectCode != null || projectName != null) ...[
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (projectCode != null)
                  Text(
                    projectCode!,
                    style: const TextStyle(
                      color: fsdPink,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                if (projectName != null)
                  Text(
                    projectName!,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── View toggle buttons ──────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final _ViewMode viewMode;
  final ValueChanged<_ViewMode> onChanged;
  final bool isDark;

  const _ViewToggle({
    required this.viewMode,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);
    final bgInactive = isDark ? const Color(0xFF252838) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgInactive,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(
            label: 'Día',
            selected: viewMode == _ViewMode.day,
            onTap: () => onChanged(_ViewMode.day),
            first: true,
            last: false,
            isDark: isDark,
          ),
          Container(width: 0.5, height: 26, color: borderColor),
          _ToggleBtn(
            label: 'Semana',
            selected: viewMode == _ViewMode.week,
            onTap: () => onChanged(_ViewMode.week),
            first: false,
            last: false,
            isDark: isDark,
          ),
          Container(width: 0.5, height: 26, color: borderColor),
          _ToggleBtn(
            label: 'Mes',
            selected: viewMode == _ViewMode.month,
            onTap: () => onChanged(_ViewMode.month),
            first: false,
            last: true,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool first;
  final bool last;
  final bool isDark;

  const _ToggleBtn({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.first,
    required this.last,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.horizontal(
      left: first ? const Radius.circular(9) : Radius.zero,
      right: last ? const Radius.circular(9) : Radius.zero,
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? fsdPink : Colors.transparent,
          borderRadius: radius,
          boxShadow: selected
              ? [BoxShadow(color: fsdPink.withValues(alpha: 0.3), blurRadius: 6)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : isDark
                    ? fsdTextGrey
                    : const Color(0xFF4B5563),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Gantt view ───────────────────────────────────────────────────────────────

class _GanttView extends StatefulWidget {
  final List<Task> tasks;
  final _ViewMode viewMode;
  final bool isDark;

  const _GanttView({
    required this.tasks,
    required this.viewMode,
    required this.isDark,
  });

  @override
  State<_GanttView> createState() => _GanttViewState();
}

class _GanttViewState extends State<_GanttView> {
  // Horizontal: header timeline ↔ body timeline
  final _hHeaderCtrl = ScrollController();
  final _hBodyCtrl = ScrollController();
  // Vertical: left names column ↔ body timeline
  final _vLeftCtrl = ScrollController();
  final _vBodyCtrl = ScrollController();

  bool _syncingH = false;
  bool _syncingV = false;

  @override
  void initState() {
    super.initState();
    _hHeaderCtrl.addListener(_onHHeader);
    _hBodyCtrl.addListener(_onHBody);
    _vLeftCtrl.addListener(_onVLeft);
    _vBodyCtrl.addListener(_onVBody);
  }

  void _onHHeader() {
    if (_syncingH) return;
    _syncingH = true;
    if (_hBodyCtrl.hasClients) _hBodyCtrl.jumpTo(_hHeaderCtrl.offset);
    _syncingH = false;
  }

  void _onHBody() {
    if (_syncingH) return;
    _syncingH = true;
    if (_hHeaderCtrl.hasClients) _hHeaderCtrl.jumpTo(_hBodyCtrl.offset);
    _syncingH = false;
  }

  void _onVLeft() {
    if (_syncingV) return;
    _syncingV = true;
    if (_vBodyCtrl.hasClients) _vBodyCtrl.jumpTo(_vLeftCtrl.offset);
    _syncingV = false;
  }

  void _onVBody() {
    if (_syncingV) return;
    _syncingV = true;
    if (_vLeftCtrl.hasClients) _vLeftCtrl.jumpTo(_vBodyCtrl.offset);
    _syncingV = false;
  }

  @override
  void dispose() {
    _hHeaderCtrl.dispose();
    _hBodyCtrl.dispose();
    _vLeftCtrl.dispose();
    _vBodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final isDark = widget.isDark;
    final tasks = widget.tasks;

    late DateTime minDate;
    late DateTime maxDate;
    late double dayWidth;

    switch (widget.viewMode) {
      case _ViewMode.day:
        minDate = todayNorm.subtract(const Duration(days: 3));
        maxDate = todayNorm.add(const Duration(days: 3));
        dayWidth = 52.0;
        break;
      case _ViewMode.week:
        minDate = todayNorm.subtract(const Duration(days: 6));
        maxDate = todayNorm.add(const Duration(days: 7));
        dayWidth = 42.0;
        break;
      case _ViewMode.month:
        DateTime rawMin = tasks
            .map((t) => t.startDate!)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        DateTime rawMax = tasks
            .map((t) => t.endDate!)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        minDate = DateTime(rawMin.year, rawMin.month, rawMin.day)
            .subtract(const Duration(days: 3));
        maxDate = DateTime(rawMax.year, rawMax.month, rawMax.day)
            .add(const Duration(days: 3));
        dayWidth = 36.0;
        break;
    }

    final totalDays = maxDate.difference(minDate).inDays + 1;
    final dates = List.generate(totalDays, (i) => minDate.add(Duration(days: i)));
    final monthGroups = _buildMonthGroups(dates);
    final todayOffset = todayNorm.difference(minDate).inDays;

    final borderColor = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);
    final headerBg = isDark ? const Color(0xFF252838) : const Color(0xFFF6F7FB);
    final nameBg = isDark ? const Color(0xFF252838) : const Color(0xFFF6F7FB);
    final titleColor = isDark ? Colors.white : const Color(0xFF151823);

    const nameWidth = 240.0;
    const rowHeight = 54.0;
    const barHeight = 26.0;
    const monthHeaderH = 24.0;
    const dayHeaderH = 38.0;
    const headerH = monthHeaderH + dayHeaderH;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Legend ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _StatusLegend(isDark: isDark),
        ),
        const SizedBox(height: 14),
        // ── Chart ──────────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? fsdCardBg : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    // ── Fixed header row ────────────────────────────
                    SizedBox(
                      height: headerH,
                      child: Row(
                        children: [
                          // Left header (fixed)
                          Container(
                            width: nameWidth,
                            height: headerH,
                            decoration: BoxDecoration(
                              color: headerBg,
                              border: Border(
                                right: BorderSide(color: borderColor, width: 0.5),
                                bottom: BorderSide(color: borderColor),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Month row area
                                Container(
                                  height: monthHeaderH,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'TAREAS Y ENTREGAS',
                                    style: TextStyle(
                                      color: isDark ? fsdTextGrey : const Color(0xFF6B7280),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                // Day row area — task count badge
                                Container(
                                  height: dayHeaderH,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: fsdPink, width: 1.5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${tasks.length}',
                                        style: const TextStyle(
                                          color: fsdPink,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Right header (scrolls horizontal, synced with body)
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              controller: _hHeaderCtrl,
                              physics: const ClampingScrollPhysics(),
                              child: SizedBox(
                                width: dayWidth * totalDays,
                                height: headerH,
                                child: Column(
                                  children: [
                                    // Month row
                                    Container(
                                      height: monthHeaderH,
                                      color: headerBg,
                                      child: Row(
                                        children: monthGroups.map((mg) => SizedBox(
                                          width: dayWidth * mg.days,
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
                                        )).toList(),
                                      ),
                                    ),
                                    // Day row
                                    Container(
                                      height: dayHeaderH,
                                      decoration: BoxDecoration(
                                        color: headerBg,
                                        border: Border(bottom: BorderSide(color: borderColor)),
                                      ),
                                      child: Row(
                                        children: dates.map((d) {
                                          final isToday = d.year == today.year &&
                                              d.month == today.month &&
                                              d.day == today.day;
                                          final isWeekend = d.weekday == DateTime.saturday ||
                                              d.weekday == DateTime.sunday;
                                          final dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
                                          return SizedBox(
                                            width: dayWidth,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  dayNames[d.weekday - 1],
                                                  style: TextStyle(
                                                    color: isToday
                                                        ? fsdPink
                                                        : isWeekend
                                                            ? fsdPink.withValues(alpha: isDark ? 0.5 : 0.7)
                                                            : isDark
                                                                ? fsdTextGrey.withValues(alpha: 0.6)
                                                                : const Color(0xFF9CA3AF),
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Container(
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
                                                            : isWeekend
                                                                ? fsdPink.withValues(alpha: isDark ? 0.6 : 0.8)
                                                                : isDark
                                                                    ? fsdTextGrey
                                                                    : const Color(0xFF6B7280),
                                                        fontSize: 10,
                                                        fontWeight: isToday
                                                            ? FontWeight.w800
                                                            : FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Body ────────────────────────────────────────
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left column — fixed, scrolls vertical only
                          SizedBox(
                            width: nameWidth,
                            child: SingleChildScrollView(
                              controller: _vLeftCtrl,
                              physics: const ClampingScrollPhysics(),
                              child: Column(
                                children: tasks.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final task = entry.value;
                                  final isLast = i == tasks.length - 1;
                                  return GestureDetector(
                                    onTap: () => _showDetail(context, task),
                                    child: Container(
                                      width: nameWidth,
                                      height: rowHeight,
                                      decoration: BoxDecoration(
                                        color: nameBg,
                                        border: Border(
                                          right: BorderSide(color: borderColor, width: 0.5),
                                          bottom: isLast
                                              ? BorderSide.none
                                              : BorderSide(color: borderColor, width: 0.5),
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 3,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: task.priorityColor,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  task.title,
                                                  style: TextStyle(
                                                    color: titleColor,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.2,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 3),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 1,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: task.statusColor.withValues(alpha: 0.15),
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
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          // Right timeline — scrolls horizontal + vertical (synced)
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              controller: _hBodyCtrl,
                              physics: const ClampingScrollPhysics(),
                              child: SizedBox(
                                width: dayWidth * totalDays,
                                child: SingleChildScrollView(
                                  controller: _vBodyCtrl,
                                  physics: const ClampingScrollPhysics(),
                                  child: Column(
                                    children: tasks.asMap().entries.map((entry) {
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
                                      final startOffset = start
                                          .difference(minDate)
                                          .inDays
                                          .clamp(0, totalDays);
                                      final endOffset = end
                                          .difference(minDate)
                                          .inDays
                                          .clamp(0, totalDays - 1);
                                      final barDays =
                                          (endOffset - startOffset + 1).clamp(1, totalDays);
                                      final barLeft = dayWidth * startOffset;
                                      final barWidth = (dayWidth * barDays).clamp(
                                        dayWidth * 0.5,
                                        dayWidth * totalDays.toDouble(),
                                      );
                                      final taskColor = task.taskColor;
                                      final rowBg = isDark
                                          ? (i.isEven ? fsdCardBg : const Color(0xFF262830))
                                          : (i.isEven ? Colors.white : const Color(0xFFFAFAFC));

                                      return GestureDetector(
                                        onTap: () => _showDetail(context, task),
                                        child: SizedBox(
                                          width: dayWidth * totalDays,
                                          height: rowHeight,
                                          child: Stack(
                                            clipBehavior: Clip.hardEdge,
                                            children: [
                                              // Row background
                                              Positioned.fill(
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: rowBg,
                                                    border: isLast
                                                        ? null
                                                        : Border(
                                                            bottom: BorderSide(
                                                              color: borderColor,
                                                              width: 0.5,
                                                            ),
                                                          ),
                                                  ),
                                                ),
                                              ),
                                              // Weekend shading
                                              ...List.generate(totalDays, (di) {
                                                final d = minDate.add(Duration(days: di));
                                                final isWe =
                                                    d.weekday == DateTime.saturday ||
                                                    d.weekday == DateTime.sunday;
                                                if (!isWe) return const SizedBox.shrink();
                                                return Positioned(
                                                  left: dayWidth * di,
                                                  top: 0,
                                                  bottom: 0,
                                                  width: dayWidth,
                                                  child: Container(
                                                    color: isDark
                                                        ? Colors.white.withValues(alpha: 0.03)
                                                        : Colors.black.withValues(alpha: 0.02),
                                                  ),
                                                );
                                              }),
                                              // Today line
                                              if (todayOffset >= 0 && todayOffset < totalDays)
                                                Positioned(
                                                  left: dayWidth * todayOffset +
                                                      dayWidth / 2 - 0.5,
                                                  top: 0,
                                                  bottom: 0,
                                                  width: 1,
                                                  child: Container(
                                                    color: fsdPink.withValues(alpha: 0.35),
                                                  ),
                                                ),
                                              // Task bar
                                              Positioned(
                                                left: barLeft,
                                                top: (rowHeight - barHeight) / 2,
                                                child: Container(
                                                  width: barWidth,
                                                  height: barHeight,
                                                  decoration: BoxDecoration(
                                                    color: taskColor.withValues(alpha: 0.88),
                                                    borderRadius: BorderRadius.circular(7),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: taskColor.withValues(alpha: 0.28),
                                                        blurRadius: 5,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  padding: const EdgeInsets.symmetric(horizontal: 7),
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
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
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
            ),
          ),
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TaskDetailSheet(task: task, isDark: widget.isDark),
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
                  style: TextStyle(
                    color: isDark ? fsdTextGrey : const Color(0xFF6B7280),
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
  final double dayWidth;
  final bool isDark;

  static const double _nameWidth = 240.0;
  static const double _rowHeight = 54.0;
  static const double _barHeight = 26.0;
  static const double _monthHeaderH = 24.0;
  static const double _dayHeaderH = 36.0;

  const _GanttChart({
    required this.tasks,
    required this.minDate,
    required this.maxDate,
    required this.totalDays,
    required this.dayWidth,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final todayOffset = todayNorm.difference(minDate).inDays;

    final dates = List.generate(totalDays, (i) => minDate.add(Duration(days: i)));
    final monthGroups = _buildMonthGroups(dates);

    final borderColor = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);
    final headerBg = isDark ? const Color(0xFF252838) : const Color(0xFFF6F7FB);
    final nameBg = isDark ? const Color(0xFF252838) : const Color(0xFFF6F7FB);
    final titleColor = isDark ? Colors.white : const Color(0xFF151823);

    return SizedBox(
      width: _nameWidth + dayWidth * totalDays,
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
                // TAREAS Y ENTREGAS label column
                Container(
                  width: _nameWidth,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'TAREAS Y ENTREGAS',
                    style: TextStyle(
                      color: isDark ? fsdTextGrey : const Color(0xFF6B7280),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                ...monthGroups.map(
                  (mg) => SizedBox(
                    width: dayWidth * mg.days,
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
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                // Count badge
                Container(
                  width: _nameWidth,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: fsdPink, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            '${tasks.length}',
                            style: const TextStyle(
                              color: fsdPink,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...dates.map((d) {
                  final isToday = d.year == today.year &&
                      d.month == today.month &&
                      d.day == today.day;
                  final isWeekend = d.weekday == DateTime.saturday ||
                      d.weekday == DateTime.sunday;
                  final dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
                  final dayName = dayNames[d.weekday - 1];
                  return SizedBox(
                    width: dayWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayName,
                          style: TextStyle(
                            color: isToday
                                ? fsdPink
                                : isWeekend
                                    ? fsdPink.withValues(alpha: isDark ? 0.5 : 0.7)
                                    : isDark
                                        ? fsdTextGrey.withValues(alpha: 0.6)
                                        : const Color(0xFF9CA3AF),
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
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
                                    : isWeekend
                                        ? fsdPink.withValues(alpha: isDark ? 0.6 : 0.8)
                                        : isDark
                                            ? fsdTextGrey
                                            : const Color(0xFF6B7280),
                                fontSize: 10,
                                fontWeight: isToday
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
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
            final barLeft = dayWidth * startOffset;
            final barWidth = (dayWidth * barDays).clamp(
              dayWidth * 0.5,
              dayWidth * totalDays.toDouble(),
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
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 30,
                            decoration: BoxDecoration(
                              color: task.priorityColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  task.title,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: task.statusColor.withValues(alpha: 0.15),
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
                        ],
                      ),
                    ),
                    // Timeline column
                    SizedBox(
                      width: dayWidth * totalDays,
                      height: _rowHeight,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          // Weekend shading
                          ...List.generate(totalDays, (di) {
                            final d = minDate.add(Duration(days: di));
                            final isWe = d.weekday == DateTime.saturday ||
                                d.weekday == DateTime.sunday;
                            if (!isWe) return const SizedBox.shrink();
                            return Positioned(
                              left: dayWidth * di,
                              top: 0,
                              bottom: 0,
                              width: dayWidth,
                              child: Container(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : Colors.black.withValues(alpha: 0.02),
                              ),
                            );
                          }),
                          // Today line
                          if (todayOffset >= 0 && todayOffset < totalDays)
                            Positioned(
                              left: dayWidth * todayOffset +
                                  dayWidth / 2 -
                                  0.5,
                              top: 0,
                              bottom: 0,
                              width: 1,
                              child: Container(
                                color: fsdPink.withValues(alpha: 0.35),
                              ),
                            ),
                          // Task bar
                          Positioned(
                            left: barLeft,
                            top: (_rowHeight - _barHeight) / 2,
                            child: Container(
                              width: barWidth,
                              height: _barHeight,
                              decoration: BoxDecoration(
                                color: taskColor.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(7),
                                boxShadow: [
                                  BoxShadow(
                                    color: taskColor.withValues(alpha: 0.28),
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

    return SafeArea(
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 30,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Row(
                      children: [
                        _InfoPill(label: task.statusLabel, color: task.statusColor),
                        const SizedBox(width: 8),
                        _InfoPill(
                          label: 'Prioridad: ${task.priorityLabel}',
                          color: task.priorityColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                                  style: TextStyle(color: subColor, fontSize: 12),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Divider(color: border, height: 1),
                      const SizedBox(height: 12),
                      Text(
                        task.description,
                        style: TextStyle(color: subColor, fontSize: 13, height: 1.5),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
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
        color: color.withValues(alpha: 0.15),
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

class _EmptyTasksState extends StatelessWidget {
  const _EmptyTasksState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF151823);
    final subColor = isDark ? fsdTextGrey : const Color(0xFF6B7280);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_rounded,
              size: 52,
              color: isDark
                  ? fsdTextGrey.withValues(alpha: 0.4)
                  : const Color(0xFFD1D5DB)),
          const SizedBox(height: 16),
          Text(
            'Sin tareas con fechas',
            style: TextStyle(
              color: titleColor,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Este proyecto no tiene tareas\ncon fechas de inicio y fin definidas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: subColor, height: 1.5),
          ),
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF151823);
    final subColor = isDark ? fsdTextGrey : const Color(0xFF6B7280);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: fsdPink),
          const SizedBox(height: 14),
          Text(
            'Error al cargar',
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message.replaceFirst('Exception: ', ''),
            textAlign: TextAlign.center,
            style: TextStyle(color: subColor, fontSize: 13),
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
    );
  }
}
