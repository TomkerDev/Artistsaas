import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/errors/firestore_error_message.dart';
import '../services/supabase_storage_service.dart';
import 'admin_identity.dart';
import 'admin_routes.dart';

/// Page « Paramètres » du panneau d'administration.
///
/// Point d'entrée de deux pans interactifs :
///  • la **gestion des rôles** (`admin_users` dans Firestore), réservée aux
///    comptes `agency_admin` ;
///  • la **configuration système** (variables de build, diagnostic).
///
/// Chaque carte ouvre une vue dédiée plein écran, cohérente avec le thème
/// sombre du panneau et le shell de navigation existant.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(
            'Administration',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: <Widget>[
              _SettingsMenuCard(
                icon: Icons.shield_outlined,
                iconColor: colors.primary,
                title: 'Rôles utilisateurs',
                subtitle: 'Gérez les comptes du panneau et leurs rôles '
                    '(artist, agency_admin) dans Firestore.',
                cta: 'Gérer les accès',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const UserRolesPanel(),
                  ),
                ),
              ),
              _SettingsMenuCard(
                icon: Icons.cloud_outlined,
                iconColor: colors.tertiary,
                title: 'Configuration Firestore / Supabase',
                subtitle: 'Informations système, diagnostic du build et accès '
                    'aux consoles.',
                cta: 'Voir la configuration',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SystemConfigPanel(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Carte d'entrée d'une section des paramètres.
class _SettingsMenuCard extends StatelessWidget {
  const _SettingsMenuCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return SizedBox(
      width: 360,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: iconColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    cta,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Brouillon d'un compte administrateur, renvoyé par la boîte de dialogue
/// d'édition et persisté par [UserRolesPanel].
@immutable
class _AdminUserDraft {
  const _AdminUserDraft({
    required this.uid,
    required this.email,
    required this.role,
    required this.assignedArtistId,
  });

  final String uid;
  final String email;
  final String role;
  final String assignedArtistId;
}

/// Libellé lisible d'un rôle Firestore.
String _roleLabel(String role) => switch (role) {
      AdminRole.agencyAdmin => 'Administrateur (agence)',
      AdminRole.artist => 'Artiste',
      _ => role,
    };

/// Libellé lisible d'un `assignedArtistId`.
String _assignedLabel(String assigned) {
  if (assigned.isEmpty) {
    return '—';
  }
  if (assigned == AdminRole.allArtists) {
    return 'Tous les artistes';
  }
  return adminArtistName(assigned);
}

/// Gestion interactive des comptes du panneau (`admin_users`).
///
/// La collection est écoutée en temps réel : toute création, modification ou
/// suppression se reflète immédiatement. Les écritures sont réservées aux
/// comptes `agency_admin` (voir `firestore.rules`) ; un compte ne peut pas
/// modifier son propre document, ses actions sont donc désactivées sur sa
/// ligne.
class UserRolesPanel extends StatefulWidget {
  const UserRolesPanel({super.key});

  @override
  State<UserRolesPanel> createState() => _UserRolesPanelState();
}

class _UserRolesPanelState extends State<UserRolesPanel> {
  /// `true` pendant une écriture Firestore (ajout / édition / suppression).
  bool _busy = false;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('admin_users');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rôles utilisateurs'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Ajouter un administrateur',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: _busy ? null : () => _openEditor(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _openEditor(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Ajouter'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _users.snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (snapshot.hasError) {
            return _RolesStreamError(error: snapshot.error);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
              List<QueryDocumentSnapshot<Map<String, dynamic>>>.of(
            snapshot.data!.docs,
          );
          // Tri client stable : e-mail puis UID, l'ordre Firestore n'étant pas
          // garanti ici (pas d'index dédié à cette liste d'administration).
          docs.sort((
            QueryDocumentSnapshot<Map<String, dynamic>> a,
            QueryDocumentSnapshot<Map<String, dynamic>> b,
          ) {
            final String ea = (a.data()['email'] as String?) ?? a.id;
            final String eb = (b.data()['email'] as String?) ?? b.id;
            final int byEmail = ea.compareTo(eb);
            return byEmail != 0 ? byEmail : a.id.compareTo(b.id);
          });

          if (docs.isEmpty) {
            return const _RolesEmptyState();
          }

          return Stack(
            children: <Widget>[
              ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int index) {
                  final QueryDocumentSnapshot<Map<String, dynamic>> doc =
                      docs[index];
                  final Map<String, dynamic> data = doc.data();
                  final bool isSelf = doc.id == _currentUid;
                  return _AdminUserTile(
                    uid: doc.id,
                    email: (data['email'] as String?) ?? '',
                    role: (data['role'] as String?) ?? AdminRole.artist,
                    assignedArtistId:
                        (data['assignedArtistId'] as String?) ?? '',
                    isSelf: isSelf,
                    onEdit: _busy
                        ? null
                        : () => _openEditor(
                              initial: _AdminUserDraft(
                                uid: doc.id,
                                email: (data['email'] as String?) ?? '',
                                role: (data['role'] as String?) ??
                                    AdminRole.artist,
                                assignedArtistId:
                                    (data['assignedArtistId'] as String?) ?? '',
                              ),
                            ),
                    onDelete: _busy ? null : () => _confirmDelete(doc.id),
                  );
                },
              ),
              if (_busy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Ouvre l'éditeur d'un compte, puis persiste le brouillon renvoyé.
  Future<void> _openEditor({_AdminUserDraft? initial}) async {
    final _AdminUserDraft? draft = await showDialog<_AdminUserDraft>(
      context: context,
      builder: (BuildContext dialogContext) =>
          _AdminUserDialog(initial: initial),
    );
    if (draft == null) {
      return;
    }
    await _persist(draft, existingUid: initial?.uid);
  }

  /// Crée ou met à jour le document `admin_users/{uid}`.
  Future<void> _persist(_AdminUserDraft draft, {String? existingUid}) async {
    setState(() => _busy = true);
    try {
      final Map<String, Object?> payload = <String, Object?>{
        'role': draft.role,
        'assignedArtistId': draft.assignedArtistId,
        if (draft.email.trim().isNotEmpty) 'email': draft.email.trim(),
      };
      if (existingUid != null) {
        await _users.doc(existingUid).update(payload);
        _toast('Rôle mis à jour.');
      } else {
        await _users.doc(draft.uid).set(<String, Object?>{
          ...payload,
          'created_at': FieldValue.serverTimestamp(),
        });
        _toast('Administrateur ajouté.');
      }
    } on FirebaseException catch (error) {
      _toast('Échec : ${_errorMessage(error)}');
    } catch (error) {
      _toast('Échec : $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Demande confirmation puis supprime l'accès.
  Future<void> _confirmDelete(String uid) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Révoquer l\'accès'),
        content: Text(
          'Retirer le compte « $uid » de la liste des administrateurs ? '
          'Il perdra immédiatement l\'accès au panneau.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Révoquer'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _users.doc(uid).delete();
      _toast('Accès révoqué.');
    } on FirebaseException catch (error) {
      _toast('Échec : ${_errorMessage(error)}');
    } catch (error) {
      _toast('Échec : $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Message d'erreur lisible pour une écriture refusée par Firestore.
  String _errorMessage(FirebaseException error) => firestoreErrorMessage(
        error,
        fallback: error.message ?? 'Erreur Firestore',
      );

  /// Message court dans un [SnackBar] (no-op si démonté).
  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Ligne d'un compte administrateur dans la liste.
class _AdminUserTile extends StatelessWidget {
  const _AdminUserTile({
    required this.uid,
    required this.email,
    required this.role,
    required this.assignedArtistId,
    required this.isSelf,
    required this.onEdit,
    required this.onDelete,
  });

  final String uid;
  final String email;
  final String role;
  final String assignedArtistId;
  final bool isSelf;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isAgency = role == AdminRole.agencyAdmin;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: (isAgency ? colors.primary : colors.tertiary)
                  .withValues(alpha: 0.15),
              foregroundColor: isAgency ? colors.primary : colors.tertiary,
              child: Icon(
                isAgency ? Icons.verified_user : Icons.person,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          email.isEmpty ? uid : email,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isSelf) ...<Widget>[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'vous',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'UID : $uid',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: <Widget>[
                      _Tag(
                          icon: Icons.shield_outlined, label: _roleLabel(role)),
                      _Tag(
                        icon: Icons.person_outline,
                        label: _assignedLabel(assignedArtistId),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelf)
              // Un compte ne peut pas se modifier lui-même (règles Firestore).
              Tooltip(
                message: 'Vous ne pouvez pas modifier votre propre compte.',
                child: Icon(Icons.lock_outline, color: colors.onSurfaceVariant),
              )
            else
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Modifier le rôle',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Révoquer l\'accès',
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, color: colors.error),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Petite étiquette informative (rôle, artiste assigné).
class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// Boîte de dialogue de création / édition d'un compte administrateur.
class _AdminUserDialog extends StatefulWidget {
  const _AdminUserDialog({this.initial});

  /// Brouillon pré-rempli en mode édition ; `null` en création.
  final _AdminUserDraft? initial;

  @override
  State<_AdminUserDialog> createState() => _AdminUserDialogState();
}

class _AdminUserDialogState extends State<_AdminUserDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _uid = TextEditingController(
    text: widget.initial?.uid ?? '',
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.initial?.email ?? '',
  );
  late String _role = widget.initial?.role ?? AdminRole.artist;
  late String _assigned =
      widget.initial?.assignedArtistId ?? adminArtistOptions.first.id;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _uid.dispose();
    _email.dispose();
    super.dispose();
  }

  /// Le rôle « agence » couvre tous les artistes : on force `assignedArtistId`.
  void _onRoleChanged(String? role) {
    if (role == null) {
      return;
    }
    setState(() {
      _role = role;
      if (role == AdminRole.agencyAdmin) {
        _assigned = AdminRole.allArtists;
      } else if (_assigned == AdminRole.allArtists) {
        _assigned = adminArtistOptions.first.id;
      }
    });
  }

  void _submit() {
    if (!_form.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _AdminUserDraft(
        uid: _uid.text.trim(),
        email: _email.text.trim(),
        role: _role,
        assignedArtistId:
            _role == AdminRole.agencyAdmin ? AdminRole.allArtists : _assigned,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<AdminArtistOption> artists = adminArtistOptions;
    final bool agency = _role == AdminRole.agencyAdmin;

    return AlertDialog(
      title: Text(_isEdit ? 'Modifier le rôle' : 'Ajouter un administrateur'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _uid,
                enabled: !_isEdit,
                decoration: InputDecoration(
                  labelText: 'UID Firebase Auth',
                  helperText: _isEdit
                      ? null
                      : 'Identifiant du compte, visible dans Firebase Auth.',
                  prefixIcon: const Icon(Icons.fingerprint),
                ),
                validator: (String? value) =>
                    (value ?? '').trim().isEmpty ? 'UID requis.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'Email (affichage)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Rôle',
                  prefixIcon: Icon(Icons.shield_outlined),
                ),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: AdminRole.artist,
                    child: Text(_roleLabel(AdminRole.artist)),
                  ),
                  DropdownMenuItem<String>(
                    value: AdminRole.agencyAdmin,
                    child: Text(_roleLabel(AdminRole.agencyAdmin)),
                  ),
                ],
                onChanged: _onRoleChanged,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: agency ? AdminRole.allArtists : _assigned,
                decoration: InputDecoration(
                  labelText: 'Artiste assigné',
                  prefixIcon: const Icon(Icons.person_outline),
                  helperText: agency
                      ? 'Un administrateur d\'agence couvre tous les artistes.'
                      : null,
                ),
                items: <DropdownMenuItem<String>>[
                  if (agency)
                    const DropdownMenuItem<String>(
                      value: AdminRole.allArtists,
                      child: Text('Tous les artistes'),
                    ),
                  for (final AdminArtistOption option in artists)
                    DropdownMenuItem<String>(
                      value: option.id,
                      child: Text('${option.name} — ${option.id}'),
                    ),
                ],
                onChanged: agency
                    ? null
                    : (String? value) {
                        if (value != null) {
                          setState(() => _assigned = value);
                        }
                      },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEdit ? 'Enregistrer' : 'Ajouter'),
        ),
      ],
    );
  }
}

/// État vide de la liste des rôles.
class _RolesEmptyState extends StatelessWidget {
  const _RolesEmptyState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.group_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Aucun administrateur déclaré.',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Ajoutez un compte pour ouvrir l\'accès au panneau.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Erreur de flux Firestore pour la liste des rôles.
class _RolesStreamError extends StatelessWidget {
  const _RolesStreamError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool indexPending = isMissingFirestoreIndex(error);
    final String message = indexPending
        ? 'Index Firestore en cours de création. Rechargez dans un instant.'
        : 'Impossible de charger les comptes du panneau.\n'
            'Cette section est réservée aux administrateurs d\'agence.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Panneau « Configuration & Système » : diagnostic du build et raccourcis.
class SystemConfigPanel extends StatelessWidget {
  const SystemConfigPanel({super.key});

  /// ID du projet Firebase de l'application initialisée, `''` si indisponible.
  String get _projectId {
    try {
      return Firebase.app().options.projectId;
    } on Object {
      return '';
    }
  }

  /// Environnement de compilation courant.
  String get _environment => kReleaseMode ? 'Release' : 'Debug';

  Future<void> _copyDiagnostics(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnostics copiés dans le presse-papiers.'),
      ),
    );
  }

  Future<void> _launch(BuildContext context, Uri url, String label) async {
    final bool ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ouverture impossible : $label.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String projectId = _projectId;
    final String? supabaseUrl = SupabaseStorageService.url;

    final Uri firebaseConsole = Uri.parse(
      projectId.isEmpty
          ? 'https://console.firebase.google.com/'
          : 'https://console.firebase.google.com/project/$projectId/overview',
    );
    final Uri supabaseConsole = Uri.parse('https://supabase.com/dashboard');

    return Scaffold(
      appBar: AppBar(title: const Text('Configuration & Système')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
          final String version = snapshot.data == null
              ? '—'
              : '${snapshot.data!.version} (build ${snapshot.data!.buildNumber})';

          final String diagnostics = <String>[
            'NOVAA — Administration',
            'Environnement : $_environment',
            'Version : $version',
            'Firebase — Projet : ${projectId.isEmpty ? '—' : projectId}',
            'Supabase — URL : ${supabaseUrl ?? 'non configurée'}',
          ].join('\n');

          return ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              _ConfigSection(
                title: 'Environnement',
                children: <Widget>[
                  _ConfigRow(
                    icon: Icons.developer_mode,
                    label: 'Mode de build',
                    value: _environment,
                    valueColor: _environment == 'Release'
                        ? Colors.greenAccent
                        : colors.primary,
                  ),
                  _ConfigRow(
                    icon: Icons.numbers,
                    label: 'Version du panneau',
                    value: version,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ConfigSection(
                title: 'Services',
                children: <Widget>[
                  _ConfigRow(
                    icon: Icons.cloud_outlined,
                    label: 'URL Supabase',
                    value: supabaseUrl ?? 'Non configurée',
                    valueColor: supabaseUrl == null ? colors.error : null,
                  ),
                  _ConfigRow(
                    icon: Icons.local_fire_department,
                    label: 'Projet Firebase',
                    value: projectId.isEmpty ? 'Non initialisé' : projectId,
                    valueColor: projectId.isEmpty ? colors.error : null,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () => _copyDiagnostics(context, diagnostics),
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Copier les diagnostics'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _launch(
                      context,
                      firebaseConsole,
                      'Console Firebase',
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Console Firebase'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _launch(
                      context,
                      supabaseConsole,
                      'Console Supabase',
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Console Supabase'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Regroupe des lignes de configuration sous un titre.
class _ConfigSection extends StatelessWidget {
  const _ConfigSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Ligne « libellé / valeur » d'une section de configuration.
class _ConfigRow extends StatelessWidget {
  const _ConfigRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor ?? colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
