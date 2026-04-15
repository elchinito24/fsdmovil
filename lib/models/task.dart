import 'package:flutter/material.dart';

class Task {
  final int id;
  final String title;
  final String description;
  final String status;
  final String priority;
  final DateTime? startDate;
  final DateTime? endDate;
  final int sortOrder;
  final String color;
  final int? assignee;
  final String assigneeName;
  final String assigneeEmail;
  final int project;
  final String projectCode;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.status = '',
    this.priority = '',
    this.startDate,
    this.endDate,
    this.sortOrder = 0,
    this.color = '',
    this.assignee,
    this.assigneeName = '',
    this.assigneeEmail = '',
    required this.project,
    this.projectCode = '',
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      priority: (json['priority'] ?? '').toString(),
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      color: (json['color'] ?? '').toString(),
      assignee: json['assignee'] != null ? (json['assignee'] as num).toInt() : null,
      assigneeName: (json['assignee_name'] ?? '').toString(),
      assigneeEmail: (json['assignee_email'] ?? '').toString(),
      project: (json['project'] as num?)?.toInt() ?? 0,
      projectCode: (json['project_code'] ?? '').toString(),
    );
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null || val.toString().trim().isEmpty) return null;
    try {
      return DateTime.parse(val.toString());
    } catch (_) {
      return null;
    }
  }

  Color get taskColor {
    final hex = color.trim();
    if (hex.startsWith('#') && hex.length >= 7) {
      try {
        final raw = hex.replaceAll('#', '');
        final padded = raw.length == 6 ? 'FF$raw' : raw;
        return Color(int.parse(padded, radix: 16));
      } catch (_) {}
    }
    switch (status.toLowerCase()) {
      case 'done':
      case 'completed':
        return const Color(0xFF1BC47D);
      case 'in_progress':
      case 'doing':
        return const Color(0xFF55A6FF);
      case 'cancelled':
        return const Color(0xFF8E8E93);
      default:
        return const Color(0xFFF2A91D);
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'done':
      case 'completed':
        return const Color(0xFF1BC47D);
      case 'in_progress':
      case 'doing':
        return const Color(0xFF55A6FF);
      case 'cancelled':
        return const Color(0xFF8E8E93);
      default:
        return const Color(0xFFF2A91D);
    }
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'done':
      case 'completed':
        return 'Completado';
      case 'in_progress':
      case 'doing':
        return 'En progreso';
      case 'cancelled':
        return 'Cancelado';
      case 'todo':
      case 'pending':
        return 'Por hacer';
      default:
        return status.isEmpty ? 'Pendiente' : status;
    }
  }

  String get priorityLabel {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'alta':
        return 'Alta';
      case 'medium':
      case 'media':
        return 'Media';
      case 'low':
      case 'baja':
        return 'Baja';
      default:
        return priority.isEmpty ? '-' : priority;
    }
  }

  Color get priorityColor {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'alta':
        return const Color(0xFFE8365D);
      case 'medium':
      case 'media':
        return const Color(0xFFF2A91D);
      default:
        return const Color(0xFF55A6FF);
    }
  }
}
