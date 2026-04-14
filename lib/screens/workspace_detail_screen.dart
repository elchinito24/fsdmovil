import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/services/auth_service.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';

const _pink = Color(0xFFE8365D);
const _textGrey = Color(0xFF8E8E93);

class WorkspaceDetailScreen extends StatefulWidget {
  final int workspaceId;

  const WorkspaceDetailScreen({super.key, required this.workspaceId});

  @override
  State<WorkspaceDetailScreen> createState() => _WorkspaceDetailScreenState();
}

class _WorkspaceDetailScreenState extends State<WorkspaceDetailScreen> {
  bool loading = true;
  bool membersLoading = false;
  bool invitationsLoading = false;

  bool membersExpanded = false;
  bool invitationsExpanded = false;

  final TextEditingController _projectSearchController = TextEditingController();
  String _projectQuery = '';

  String? errorMessage;

  Map<String, dynamic>? workspace;
  List<dynamic> projects = [];
  List<dynamic> members = [];
  List<dynamic> invitations = [];

  String get currentUserEmail =>
      (AuthService.userEmail ?? '').trim().toLowerCase();

  bool get isOwner {
    final owner = workspace?['owner'];
    if (owner is Map<String, dynamic>) {
      final ownerEmail = (owner['email'] ?? '').toString().trim().toLowerCase();
      return ownerEmail.isNotEmpty && ownerEmail == currentUserEmail;
    }
    return false;
  }

  String? get currentUserRole {
    for (final member in members) {
      final user = member['user'];
      if (user is Map<String, dynamic>) {
        final email = (user['email'] ?? '').toString().trim().toLowerCase();
        if (email == currentUserEmail) {
          return (member['role'] ?? '').toString().toLowerCase();
        }
      }
    }
    return null;
  }

  bool get canManageMembers {
    final role = currentUserRole;
    return isOwner || role == 'owner' || role == 'admin';
  }

  bool get canInviteMembers {
    return isOwner;
  }

  @override
  void initState() {
    super.initState();
    _projectSearchController.addListener(() {
      setState(() => _projectQuery = _projectSearchController.text.toLowerCase());
    });
    loadData();
  }

  @override
  void dispose() {
    _projectSearchController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    try {
      final wsFuture = ApiService.getWorkspaceById(widget.workspaceId);
      final prFuture = ApiService.getProjectsByWorkspace(widget.workspaceId);
      final membersFuture = ApiService.getWorkspaceMembers(widget.workspaceId);

      final results = await Future.wait([wsFuture, prFuture, membersFuture]);

      final ws = Map<String, dynamic>.from(results[0] as Map<String, dynamic>);
      final pr = List<dynamic>.from(results[1] as List<dynamic>);
      final memberList = List<dynamic>.from(results[2] as List<dynamic>);

      List<dynamic> pendingInvitations = [];
      final owner = ws['owner'];
      bool shouldLoadInvitations = false;

      if (owner is Map<String, dynamic>) {
        final ownerEmail = (owner['email'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        shouldLoadInvitations = ownerEmail == currentUserEmail;
      }

      if (shouldLoadInvitations) {
        try {
          pendingInvitations = await ApiService.getWorkspaceInvitations(
            widget.workspaceId,
          );
        } catch (_) {
          pendingInvitations = [];
        }
      }

      if (!mounted) return;

      setState(() {
        workspace = ws;
        projects = pr;
        members = memberList;
        invitations = pendingInvitations;
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

  Future<void> _reloadMembersAndInvitations() async {
    setState(() {
      membersLoading = true;
      invitationsLoading = true;
    });

    try {
      final memberList = await ApiService.getWorkspaceMembers(
        widget.workspaceId,
      );
      List<dynamic> pendingInvitations = invitations;

      if (canInviteMembers) {
        try {
          pendingInvitations = await ApiService.getWorkspaceInvitations(
            widget.workspaceId,
          );
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        members = memberList;
        invitations = pendingInvitations;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        membersLoading = false;
        invitationsLoading = false;
      });
    }
  }

  Future<void> _showInviteMemberDialog() async {
    final emailController = TextEditingController();
    String selectedRole = 'editor';
    bool submitting = false;
    String? localError;

    await showDialog(
      context: context,
      barrierDismissible: !submitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: Theme.of(ctx).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                'Invitar miembro',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Correo del usuario',
                        labelStyle: const TextStyle(color: _textGrey),
                        hintText: 'correo@ejemplo.com',
                        hintStyle: const TextStyle(color: _textGrey),
                        filled: true,
                        fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Theme.of(ctx).colorScheme.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: _pink),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          dropdownColor: Theme.of(ctx).colorScheme.surface,
                          style: const TextStyle(color: Colors.white),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'editor',
                              child: Text('Editor'),
                            ),
                            DropdownMenuItem(
                              value: 'viewer',
                              child: Text('Viewer'),
                            ),
                          ],
                          onChanged: submitting
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setModalState(() {
                                    selectedRole = value;
                                  });
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Por ahora la invitación en móvil funciona por correo. Si ese correo ya tiene cuenta, recibirá la invitación en la plataforma. Si no tiene cuenta aún, quedará pendiente para cuando se registre.',
                      style: TextStyle(
                        color: _textGrey,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        localError!,
                        style: const TextStyle(
                          color: _pink,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: _textGrey),
                  ),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final email = emailController.text
                              .trim()
                              .toLowerCase();

                          if (email.isEmpty) {
                            setModalState(() {
                              localError = 'Ingresa un correo válido.';
                            });
                            return;
                          }

                          setModalState(() {
                            submitting = true;
                            localError = null;
                          });

                          try {
                            final invitation =
                                await ApiService.inviteWorkspaceMember(
                                  workspaceId: widget.workspaceId,
                                  email: email,
                                  role: selectedRole,
                                );

                            if (!mounted) return;
                            Navigator.pop(ctx);

                            await _reloadMembersAndInvitations();

                            final inviteeExists =
                                invitation['invitee_exists'] == true;
                            final roleText = selectedRole == 'editor'
                                ? 'Editor'
                                : 'Viewer';

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  inviteeExists
                                      ? 'Invitación enviada. El usuario ya tenía cuenta y ya puede verla en la plataforma. Rol: $roleText.'
                                      : 'Invitación creada. Ese correo aún no tenía cuenta; se procesará cuando se registre. Rol: $roleText.',
                                ),
                                backgroundColor: _pink,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            setModalState(() {
                              submitting = false;
                              localError = e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Invitar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showUpdateRoleDialog(dynamic member) async {
    final currentRole = (member['role'] ?? 'viewer').toString().toLowerCase();
    String selectedRole = currentRole;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor: Theme.of(ctx).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                'Cambiar rol',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedRole,
                    dropdownColor: Theme.of(ctx).colorScheme.surface,
                    style: const TextStyle(color: Colors.white),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'editor', child: Text('Editor')),
                      DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() {
                        selectedRole = value;
                      });
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: _textGrey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await ApiService.updateWorkspaceMemberRole(
                        workspaceId: widget.workspaceId,
                        memberId: member['id'] as int,
                        role: selectedRole,
                      );

                      if (!mounted) return;
                      Navigator.pop(ctx);

                      await _reloadMembersAndInvitations();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Rol actualizado correctamente'),
                          backgroundColor: _pink,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Exception: ', ''),
                          ),
                          backgroundColor: _pink,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _removeMember(dynamic member) async {
    final user = member['user'] as Map<String, dynamic>? ?? {};
    final name = _buildUserName(user);

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              'Eliminar miembro',
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              '¿Seguro que quieres eliminar a $name del workspace?',
              style: const TextStyle(color: _textGrey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: _textGrey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pink,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await ApiService.removeWorkspaceMember(
        workspaceId: widget.workspaceId,
        memberId: member['id'] as int,
      );

      if (!mounted) return;

      await _reloadMembersAndInvitations();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Miembro eliminado correctamente'),
          backgroundColor: _pink,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: _pink,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cancelInvitation(dynamic invitation) async {
    final id = invitation['id'] as int;
    final email = (invitation['email'] ?? '').toString();

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              'Cancelar invitación',
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              '¿Seguro que quieres cancelar la invitación enviada a $email?',
              style: const TextStyle(color: _textGrey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No', style: TextStyle(color: _textGrey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pink,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sí, cancelar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await ApiService.cancelWorkspaceInvitation(
        workspaceId: widget.workspaceId,
        invitationId: id,
      );

      if (!mounted) return;

      await _reloadMembersAndInvitations();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitación cancelada'),
          backgroundColor: _pink,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: _pink,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _buildUserName(Map<String, dynamic> user) {
    final first = (user['first_name'] ?? '').toString().trim();
    final last = (user['last_name'] ?? '').toString().trim();
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    final email = (user['email'] ?? '').toString().trim();
    if (email.isNotEmpty) return email;
    return 'Usuario';
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Admin';
      case 'editor':
        return 'Editor';
      case 'viewer':
        return 'Viewer';
      default:
        return role;
    }
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return const Color(0xFF1BC47D);
      case 'admin':
        return const Color(0xFF55A6FF);
      case 'editor':
        return const Color(0xFFFFC857);
      case 'viewer':
        return _textGrey;
      default:
        return _textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspaceName = loading ? 'Cargando...' : (workspace?['name']?.toString() ?? 'Workspace');
    final wsDescription = loading ? '' : (workspace?['description']?.toString() ?? 'Sin descripción');

    return MainAppShell(
      insideShell: true,
      selectedItem: TopNavItem.workspaces,
      eyebrow: 'Espacio de trabajo',
      titleWhite: '',
      titlePink: workspaceName,
      description: wsDescription,
      useBodyPadding: true,
      onRefresh: loading ? null : loadData,
      floatingActionButton: (!loading && projects.isEmpty)
          ? FloatingActionButton.extended(
              backgroundColor: _pink,
              foregroundColor: Colors.white,
              onPressed: () => context.push('/create-project?workspaceId=${widget.workspaceId}'),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Nuevo proyecto',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          : null,
      child: loading
          ? const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator(color: _pink)),
            )
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Botones de secciones colapsables ─────────────────────
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _CollapseButton(
                          label: 'Miembros',
                          count: members.length,
                          icon: Icons.people_outline_rounded,
                          expanded: membersExpanded,
                          loading: membersLoading,
                          onTap: () => setState(() {
                            membersExpanded = !membersExpanded;
                            if (membersExpanded) invitationsExpanded = false;
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CollapseButton(
                          label: 'Invitaciones',
                          count: invitations.length,
                          icon: Icons.mail_outline_rounded,
                          expanded: invitationsExpanded,
                          loading: invitationsLoading,
                          onTap: () => setState(() {
                            invitationsExpanded = !invitationsExpanded;
                            if (invitationsExpanded) membersExpanded = false;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Panel de Miembros ─────────────────────────────────────
                if (membersExpanded) ...[
                  const SizedBox(height: 16),
                  if (canInviteMembers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showInviteMemberDialog,
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                          label: const Text(
                            'Invitar miembro',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _pink,
                            side: const BorderSide(color: _pink),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (members.isEmpty)
                    const _EmptyStateCard(
                      icon: Icons.people_outline_rounded,
                      title: 'No hay miembros',
                      subtitle: 'Aquí aparecerán los usuarios que formen parte de este workspace.',
                    )
                  else
                    ...members.map((member) {
                      final user = member['user'] as Map<String, dynamic>? ?? {};
                      final role = (member['role'] ?? 'viewer').toString();
                      final memberEmail = (user['email'] ?? '').toString().trim().toLowerCase();
                      final isCurrentUser = memberEmail == currentUserEmail;
                      final isOwnerMember = role.toLowerCase() == 'owner';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MemberCard(
                          name: _buildUserName(user),
                          email: (user['email'] ?? '').toString(),
                          roleLabel: _roleLabel(role),
                          roleColor: _roleColor(role),
                          isCurrentUser: isCurrentUser,
                          canManage: canManageMembers && !isOwnerMember,
                          onEditRole: () => _showUpdateRoleDialog(member),
                          onRemove: () => _removeMember(member),
                        ),
                      );
                    }),
                ],

                // ── Panel de Invitaciones ─────────────────────────────────
                if (invitationsExpanded) ...[
                  const SizedBox(height: 16),
                  if (invitations.isEmpty)
                    const _EmptyStateCard(
                      icon: Icons.mail_outline_rounded,
                      title: 'No hay invitaciones pendientes',
                      subtitle: 'Cuando invites personas al workspace, aquí aparecerán mientras no acepten o rechacen.',
                    )
                  else
                    ...invitations.map((invitation) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _InvitationCard(
                          email: (invitation['email'] ?? '').toString(),
                          roleLabel: _roleLabel((invitation['role'] ?? '').toString()),
                          invitedBy: (invitation['invited_by_name'] ?? '').toString(),
                          inviteeExists: invitation['invitee_exists'] == true,
                          onCancel: () => _cancelInvitation(invitation),
                        ),
                      );
                    }),
                ],

                // ── Proyectos ─────────────────────────────────────────────
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Proyectos',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/create-project?workspaceId=${widget.workspaceId}'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nuevo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Barra de búsqueda de proyectos
                TextField(
                  controller: _projectSearchController,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Buscar proyecto...',
                    hintStyle: const TextStyle(color: _textGrey),
                    prefixIcon: const Icon(Icons.search_rounded, color: _textGrey),
                    suffixIcon: _projectQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, color: _textGrey),
                            onPressed: () => _projectSearchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _pink),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Builder(builder: (context) {
                  final filtered = _projectQuery.isEmpty
                      ? projects
                      : projects.where((p) {
                          final name = (p['name'] ?? '').toString().toLowerCase();
                          final desc = (p['description'] ?? '').toString().toLowerCase();
                          final code = (p['code'] ?? '').toString().toLowerCase();
                          return name.contains(_projectQuery) ||
                              desc.contains(_projectQuery) ||
                              code.contains(_projectQuery);
                        }).toList();

                  if (projects.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.description_outlined, color: _pink, size: 34),
                          const SizedBox(height: 12),
                          Text(
                            'No hay proyectos aún',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Crea el primer proyecto de este espacio de trabajo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _textGrey, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'Sin resultados para "$_projectQuery"',
                          style: const TextStyle(color: _textGrey, fontSize: 14),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: filtered.map((project) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(21),
                            child: Dismissible(
                              key: ValueKey(project['id']),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 28),
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2A0A10)
                                    : const Color(0xFFFFEBEE),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.delete_outline_rounded, color: _pink, size: 28),
                                    SizedBox(height: 4),
                                    Text(
                                      'Eliminar',
                                      style: TextStyle(color: _pink, fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                              confirmDismiss: (_) async {
                                return await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: Theme.of(ctx).colorScheme.surface,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        title: Text(
                                          'Eliminar proyecto',
                                          style: TextStyle(
                                            color: Theme.of(ctx).colorScheme.onSurface,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        content: Text(
                                          '¿Seguro que quieres eliminar "${project['name']}"? Esta acción no se puede deshacer.',
                                          style: const TextStyle(color: _textGrey),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('Cancelar', style: TextStyle(color: _textGrey)),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _pink,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            child: const Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    ) ??
                                    false;
                              },
                              onDismissed: (_) async {
                                final removed = project;
                                setState(() {
                                  projects.removeWhere((p) => p['id'] == project['id']);
                                });
                                try {
                                  await ApiService.deleteProject(project['id']);
                                  ApiService.cacheDeletedProject(
                                      (project['name'] ?? '').toString(),
                                      project['id'] as int);
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: _pink),
                                  );
                                  setState(() => projects.add(removed));
                                }
                              },
                              child: _ProjectCard(
                                project: project,
                                onTap: () => context.push('/editor/${project['id']}'),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  final String name;
  final String email;
  final String roleLabel;
  final Color roleColor;
  final bool isCurrentUser;
  final bool canManage;
  final VoidCallback onEditRole;
  final VoidCallback onRemove;

  const _MemberCard({
    required this.name,
    required this.email,
    required this.roleLabel,
    required this.roleColor,
    required this.isCurrentUser,
    required this.canManage,
    required this.onEditRole,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0x22E8365D),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: _pink, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x22E8365D),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Tú',
                          style: TextStyle(
                            color: _pink,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textGrey, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: roleColor.withOpacity(0.35)),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(
                      color: roleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) {
                if (value == 'role') onEditRole();
                if (value == 'remove') onRemove();
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'role',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.manage_accounts_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Cambiar rol',
                        style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_remove_alt_1_rounded,
                        color: _pink,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text('Eliminar', style: TextStyle(color: _pink)),
                    ],
                  ),
                ),
              ],
              child: const Icon(Icons.more_vert_rounded, color: _textGrey),
            ),
        ],
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  final String email;
  final String roleLabel;
  final String invitedBy;
  final bool inviteeExists;
  final VoidCallback onCancel;

  const _InvitationCard({
    required this.email,
    required this.roleLabel,
    required this.invitedBy,
    required this.inviteeExists,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Color(0x22E8365D),
            child: Icon(Icons.mail_outline_rounded, color: _pink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  inviteeExists
                      ? 'Ya tiene cuenta • pendiente de responder'
                      : 'Aún no tiene cuenta • se procesará al registrarse',
                  style: const TextStyle(
                    color: _textGrey,
                    fontSize: 13.2,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x22FFC857),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        roleLabel,
                        style: const TextStyle(
                          color: Color(0xFFFFC857),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (invitedBy.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x221BC47D),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          invitedBy,
                          style: const TextStyle(
                            color: Color(0xFF1BC47D),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, color: _pink),
            tooltip: 'Cancelar invitación',
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, color: _pink, size: 36),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textGrey,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapseButton extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final bool expanded;
  final bool loading;
  final VoidCallback onTap;

  const _CollapseButton({
    required this.label,
    required this.count,
    required this.icon,
    required this.expanded,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: expanded
              ? const Color(0x22E8365D)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: expanded ? _pink : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: expanded ? _pink : _textGrey, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: expanded ? _pink : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(color: _pink, strokeWidth: 2),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: expanded ? _pink : const Color(0x22E8365D),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: expanded ? Colors.white : _pink,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Icon(
              expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: expanded ? _pink : _textGrey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final dynamic project;
  final VoidCallback onTap;

  const _ProjectCard({required this.project, required this.onTap});

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'Borrador';
      case 'in_progress':
        return 'En progreso';
      case 'review':
        return 'En revisión';
      case 'approved':
        return 'Aprobado';
      case 'completed':
        return 'Completado';
      default:
        return status.isEmpty ? 'Sin estado' : status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return const Color(0xFF55A6FF);
      case 'in_progress':
        return const Color(0xFFFFC857);
      case 'review':
        return const Color(0xFFFFA94D);
      case 'approved':
      case 'completed':
        return const Color(0xFF1BC47D);
      default:
        return _textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (project['name'] ?? 'Proyecto').toString();
    final description = (project['description'] ?? 'Sin descripción')
        .toString();
    final status = (project['status'] ?? '').toString();
    final code = (project['code'] ?? 'Sin código').toString();

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 140,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textGrey,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Flexible(
                    child: _TinyChip(icon: Icons.tag_rounded, text: code, color: _pink),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: _TinyChip(
                      icon: Icons.flag_outlined,
                      text: _statusLabel(status),
                      color: _statusColor(status),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _TinyChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
