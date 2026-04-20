import 'package:flutter/material.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';

class InvitationsScreen extends StatefulWidget {
  const InvitationsScreen({super.key});

  @override
  State<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen> {
  bool loading = true;
  String? errorMessage;
  List<dynamic> notifications = [];
  bool processing = false;

  @override
  void initState() {
    super.initState();
    loadInvitations();
  }

  Future<void> loadInvitations() async {
    try {
      final data = await ApiService.getNotifications(unreadOnly: true);

      final invitations = data.where((n) {
        final type = (n['type'] ?? '').toString();
        final invitationId = n['invitation_id'];
        return type == 'workspace_invitation' && invitationId != null;
      }).toList();

      if (!mounted) return;

      setState(() {
        notifications = invitations;
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> _acceptInvitation(dynamic notification) async {
    final invitationId = notification['invitation_id'] as int?;
    final notificationId = notification['id'] as int?;

    if (invitationId == null || notificationId == null) return;

    try {
      setState(() {
        processing = true;
      });

      await ApiService.acceptWorkspaceInvitation(invitationId);
      await ApiService.markNotificationAsRead(notificationId);

      if (!mounted) return;

      setState(() {
        notifications.removeWhere((n) => n['id'] == notificationId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitación aceptada correctamente'),
          backgroundColor: fsdPink,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: fsdPink,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        processing = false;
      });
    }
  }

  Future<void> _declineInvitation(dynamic notification) async {
    final invitationId = notification['invitation_id'] as int?;
    final notificationId = notification['id'] as int?;

    if (invitationId == null || notificationId == null) return;

    try {
      setState(() {
        processing = true;
      });

      await ApiService.declineWorkspaceInvitation(invitationId);
      await ApiService.markNotificationAsRead(notificationId);

      if (!mounted) return;

      setState(() {
        notifications.removeWhere((n) => n['id'] == notificationId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitación rechazada'),
          backgroundColor: fsdPink,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: fsdPink,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        processing = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      setState(() {
        processing = true;
      });

      await ApiService.markAllNotificationsAsRead();

      if (!mounted) return;

      setState(() {
        notifications = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todas las notificaciones fueron marcadas como leídas'),
          backgroundColor: fsdPink,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: fsdPink,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainAppShell(
      selectedItem: TopNavItem.workspaces,
      eyebrow: 'Notificaciones',
      titleWhite: 'Mis ',
      titlePink: 'invitaciones',
      description:
          'Aquí aparecen las invitaciones pendientes que recibes para unirte a workspaces.',
      insideShell: true,
      action: notifications.isNotEmpty
          ? SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: processing ? null : _markAllAsRead,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Marcar todas como leídas',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            )
          : null,
      child: loading
          ? const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator(color: fsdPink)),
            )
          : errorMessage != null
          ? _InvitationsErrorState(
              message: errorMessage!,
              onRetry: () {
                setState(() {
                  loading = true;
                });
                loadInvitations();
              },
            )
          : RefreshIndicator(
              color: fsdPink,
              onRefresh: loadInvitations,
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  if (notifications.isEmpty)
                    const _EmptyInvitationsState()
                  else
                    ...notifications.map((notification) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _InvitationNotificationCard(
                          title: (notification['title'] ?? 'Invitación')
                              .toString(),
                          body: (notification['body'] ?? '').toString(),
                          createdAt: (notification['created_at'] ?? '')
                              .toString(),
                          processing: processing,
                          onAccept: () => _acceptInvitation(notification),
                          onDecline: () => _declineInvitation(notification),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _InvitationNotificationCard extends StatelessWidget {
  final String title;
  final String body;
  final String createdAt;
  final bool processing;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InvitationNotificationCard({
    required this.title,
    required this.body,
    required this.createdAt,
    required this.processing,
    required this.onAccept,
    required this.onDecline,
  });

  String _formatDate(String raw) {
    if (raw.trim().isEmpty) return 'Sin fecha';

    try {
      final date = DateTime.parse(raw).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year} ${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: fsdPink.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0x22E8365D),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.mail_outline_rounded,
                    color: fsdPink,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: const TextStyle(
                color: fsdTextGrey,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _formatDate(createdAt),
              style: const TextStyle(
                color: fsdTextGrey,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: processing ? null : onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Rechazar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: processing ? null : onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: fsdPink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Aceptar',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyInvitationsState extends StatelessWidget {
  const _EmptyInvitationsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(Icons.notifications_none_rounded, color: fsdPink, size: 44),
          const SizedBox(height: 14),
          Text(
            'No tienes invitaciones pendientes',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Cuando alguien te invite a un workspace, aparecerá aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: fsdTextGrey, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _InvitationsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InvitationsErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: fsdPink, size: 48),
          const SizedBox(height: 14),
          Text(
            'No pudimos cargar tus invitaciones',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: fsdTextGrey,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: fsdPink,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Reintentar',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
