import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/errors/firestore_error_message.dart';
import 'admin_routes.dart';

/// Tableau de bord moderne du panneau d'administration.
///
/// Entièrement dynamique : les compteurs, le graphique d'activité et les
/// listes d'ajouts récents sont lus en direct depuis Firestore et suivent le
/// filtre artiste sélectionné en haut de page. « Tous » agrège l'ensemble des
/// artistes.
///
/// Les boutons d'action rapide délèguent la navigation au shell via
/// [onNavigate] (index de l'onglet du `NavigationRail`), évitant à
/// l'administrateur de repasser par le menu latéral.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({required this.onNavigate, super.key});

  /// Ouvre l'onglet du shell dont l'index est fourni.
  ///
  /// Les index correspondent à l'ordre du `NavigationRail` :
  /// 0 = Dashboard, 1 = Catalogue & Upload, 2 = Boutique & Shows.
  final void Function(int index) onNavigate;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  /// Artiste filtré ; `null` = tous les artistes agrégés.
  String? _artistId;

  /// Flux des morceaux, filtré par artiste lorsque l'un est choisi.
  ///
  /// Le filtre reste sur le seul champ `artistId` (index simple) afin de ne
  /// dépendre d'aucun index composite.
  Stream<QuerySnapshot<Map<String, dynamic>>> _tracksStream() {
    final CollectionReference<Map<String, dynamic>> tracks =
        FirebaseFirestore.instance.collection('tracks');
    if (_artistId == null) {
      return tracks.snapshots();
    }
    return tracks.where('artistId', isEqualTo: _artistId).snapshots();
  }

  /// Flux des articles merchandise, filtré de la même façon.
  Stream<QuerySnapshot<Map<String, dynamic>>> _merchStream() {
    final CollectionReference<Map<String, dynamic>> merch =
        FirebaseFirestore.instance.collection('merch');
    if (_artistId == null) {
      return merch.snapshots();
    }
    return merch.where('artistId', isEqualTo: _artistId).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: <Widget>[
          if (FirebaseAuth.instance.currentUser != null)
            IconButton(
              tooltip: 'Déconnexion',
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        children: <Widget>[
          _DashboardHeader(artistId: _artistId),
          const SizedBox(height: 20),
          _ArtistFilter(
            selectedId: _artistId,
            onChanged: (String? id) => setState(() => _artistId = id),
          ),
          const SizedBox(height: 20),
          // Les morceaux alimentent les KPI et le graphique d'activité.
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _tracksStream(),
            builder: (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.hasError) {
                return _DashboardError(error: snapshot.error);
              }
              if (!snapshot.hasData) {
                return const _DashboardSkeleton();
              }
              final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                  snapshot.data!.docs;
              final _CatalogStats stats = _CatalogStats.from(docs, _artistId);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _KpiGrid(stats: stats),
                  const SizedBox(height: 20),
                  _MonthlyActivity(stats: stats),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Text(
            'Activité récente',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          // Derniers morceaux (depuis le flux morceaux) et derniers articles.
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _tracksStream(),
            builder: (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (!snapshot.hasData) {
                return const _ListSkeleton();
              }
              return _RecentTracks(docs: snapshot.data!.docs);
            },
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _merchStream(),
            builder: (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (!snapshot.hasData) {
                return const _ListSkeleton();
              }
              return _RecentMerch(docs: snapshot.data!.docs);
            },
          ),
          const SizedBox(height: 28),
          Text(
            'Actions rapides',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _QuickActions(
            onUpload: () => widget.onNavigate(1),
            onMerch: () => widget.onNavigate(2),
            onEvent: () => widget.onNavigate(2),
          ),
        ],
      ),
    );
  }
}

/// En-tête du tableau de bord : salutation et périmètre courant.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.artistId});

  final String? artistId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String scope =
        artistId == null ? 'Tous les artistes' : adminArtistName(artistId!);

    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[colors.primary, colors.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.space_dashboard, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Vue d\'ensemble',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Périmètre : $scope',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sélecteur d'artiste : puces avec une entrée « Tous » en tête.
class _ArtistFilter extends StatelessWidget {
  const _ArtistFilter({required this.selectedId, required this.onChanged});

  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        ChoiceChip(
          avatar: const Icon(Icons.groups_2_outlined, size: 18),
          label: const Text('Tous'),
          selected: selectedId == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final AdminArtistOption option in adminArtistOptions)
          ChoiceChip(
            avatar: const Icon(Icons.person_outline, size: 18),
            label: Text(option.name),
            selected: selectedId == option.id,
            onSelected: (bool selected) =>
                onChanged(selected ? option.id : null),
          ),
      ],
    );
  }
}

/// Agrégats du catalogue, calculés côté client depuis les documents `tracks`.
final class _CatalogStats {
  const _CatalogStats({
    required this.tracks,
    required this.albums,
    required this.files,
    required this.plays,
    required this.monthlyCounts,
  });

  /// Nombre de morceaux publiés.
  final int tracks;

  /// Nombre d'albums/singles distincts.
  final int albums;

  /// Nombre de documents porteurs d'une URL audio.
  final int files;

  /// Total des écoutes ; `null` si aucun compteur n'est renseigné.
  final int? plays;

  /// Publications par mois sur les 6 derniers mois (index 0 = plus ancien).
  final List<int> monthlyCounts;

  factory _CatalogStats.from(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String? artistId,
  ) {
    final Set<String> albums = <String>{};
    int tracks = 0;
    int files = 0;
    int plays = 0;
    bool playsKnown = false;

    // 6 seaux mensuels glissants, du plus ancien (0) au mois courant (5).
    final List<int> monthly = List<int>.filled(6, 0);
    final DateTime now = DateTime.now();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final Map<String, dynamic> data = doc.data();

      // Sans filtre, tous les documents sont déjà reçus.
      if (artistId != null && data['artistId'] != artistId) {
        continue;
      }
      tracks++;

      final String? album = data['album'] as String?;
      albums.add(
        album != null && album.trim().isNotEmpty ? album.trim() : 'Single',
      );

      final Object? audioUrl = data['audioUrl'] ?? data['audio_url'];
      if (audioUrl is String && audioUrl.isNotEmpty) {
        files++;
      }

      final Object? count = data['plays'] ?? data['play_count'];
      if (count is num) {
        plays += count.toInt();
        playsKnown = true;
      }

      // Répartition mensuelle à partir de l'horodatage de création.
      final DateTime? created = _readDate(
        data['created_at'] ?? data['createdAt'],
      );
      if (created != null) {
        final int monthsAgo =
            (now.year - created.year) * 12 + (now.month - created.month);
        if (monthsAgo >= 0 && monthsAgo < monthly.length) {
          monthly[monthly.length - 1 - monthsAgo]++;
        }
      }
    }

    return _CatalogStats(
      tracks: tracks,
      albums: albums.length,
      files: files,
      plays: playsKnown ? plays : null,
      monthlyCounts: monthly,
    );
  }

  /// Lit un horodatage Firestore (`Timestamp`) ou un entier (millisecondes).
  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }
}

/// Grille responsive des cartes de statistiques (KPI).
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats});

  final _CatalogStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Une colonne sur mobile, deux sur tablette, quatre sur grand écran.
        final int columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 640
                ? 2
                : 1;
        const double spacing = 16;
        final double cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            _KpiCard(
              width: cardWidth,
              icon: Icons.library_music_rounded,
              accent: const Color(0xFF8B5CF6),
              label: 'Morceaux publiés',
              value: '${stats.tracks}',
              caption: 'Dans le catalogue',
            ),
            _KpiCard(
              width: cardWidth,
              icon: Icons.album_rounded,
              accent: const Color(0xFF3B82F6),
              label: 'Albums & Singles',
              value: '${stats.albums}',
              caption: 'Projets distincts',
            ),
            _KpiCard(
              width: cardWidth,
              icon: Icons.headphones_rounded,
              accent: const Color(0xFF10B981),
              label: 'Écoutes cumulées',
              value: stats.plays == null ? '—' : '${stats.plays}',
              caption: 'Toutes plateformes',
              trend: stats.plays,
            ),
            _KpiCard(
              width: cardWidth,
              icon: Icons.graphic_eq_rounded,
              accent: const Color(0xFFF59E0B),
              label: 'Fichiers audio',
              value: '${stats.files}',
              caption: 'Médias hébergés',
            ),
          ],
        );
      },
    );
  }
}

/// Carte de statistique individuelle, avec effet de survol.
class _KpiCard extends StatefulWidget {
  const _KpiCard({
    required this.width,
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.caption,
    this.trend,
  });

  final double width;
  final IconData icon;
  final Color accent;
  final String label;
  final String value;
  final String caption;

  /// Valeur de tendance ; affiche un badge « actif » si positive.
  final int? trend;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: widget.width,
        padding: const EdgeInsets.all(20),
        transform: _hovered
            ? (Matrix4.identity()..translateByDouble(0, -4, 0, 1))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovered
                ? widget.accent.withValues(alpha: 0.6)
                : colors.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: <BoxShadow>[
            if (_hovered)
              BoxShadow(
                color: widget.accent.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: widget.accent, size: 22),
                ),
                const Spacer(),
                if (widget.trend != null && widget.trend! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: <Widget>[
                        Icon(
                          Icons.trending_up,
                          size: 14,
                          color: Color(0xFF10B981),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'actif',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.caption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Graphique d'activité : publications par mois sur les 6 derniers mois.
class _MonthlyActivity extends StatelessWidget {
  const _MonthlyActivity({required this.stats});

  final _CatalogStats stats;

  /// Libellés des 6 derniers mois, du plus ancien au mois courant.
  List<String> get _monthLabels {
    const List<String> names = <String>[
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Août',
      'Sep',
      'Oct',
      'Nov',
      'Déc',
    ];
    final DateTime now = DateTime.now();
    return <String>[
      for (int i = 5; i >= 0; i--)
        names[DateTime(now.year, now.month - i).month - 1],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<String> labels = _monthLabels;
    final int total = stats.monthlyCounts.fold(0, (int a, int b) => a + b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.show_chart_rounded, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Activité de publication',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$total sur 6 mois',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (int i = 0; i < stats.monthlyCounts.length; i++)
                  Expanded(
                    child: _Bar(
                      count: stats.monthlyCounts[i],
                      label: labels[i],
                      accent: colors.primary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une barre verticale du graphique mensuel, avec sa valeur et son libellé.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.count,
    required this.label,
    required this.accent,
  });

  final int count;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text(
            count == 0 ? '' : '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          // Barre pleine hauteur ; la partie colorée suit le ratio via une
          // fraction de la hauteur disponible.
          Container(
            height: 110,
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: _heightFactor(),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: count == 0
                      ? colors.outlineVariant.withValues(alpha: 0.3)
                      : accent,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Ratio de hauteur de la barre ; plancher visible même à 1 publication.
  double _heightFactor() {
    if (count <= 0) {
      return 0.04;
    }
    return (0.2 + 0.8 * (count / (count + 2))).clamp(0.2, 1.0);
  }
}

/// Mini-liste des derniers morceaux publiés (5 maximum).
class _RecentTracks extends StatelessWidget {
  const _RecentTracks({required this.docs});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  @override
  Widget build(BuildContext context) {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> sorted =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.of(docs)
          ..sort(
            (
              QueryDocumentSnapshot<Map<String, dynamic>> a,
              QueryDocumentSnapshot<Map<String, dynamic>> b,
            ) =>
                _readMillis(b.data()).compareTo(_readMillis(a.data())),
          );
    final items = sorted.take(5).toList();

    if (items.isEmpty) {
      return const _EmptyHint(
          message: 'Aucun morceau publié pour ce périmètre.');
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
                alpha: 0.5,
              ),
        ),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < items.length; i++)
            _RecentTrackTile(
              title: _text(items[i].data()['title'], fallback: 'Sans titre'),
              album: _text(items[i].data()['album'], fallback: 'Single'),
              artistId: _optText(items[i].data()['artistId']),
              when: _readMillis(items[i].data()),
              isLast: i == items.length - 1,
            ),
        ],
      ),
    );
  }

  static int _readMillis(Map<String, dynamic> data) {
    final Object? value = data['created_at'] ?? data['createdAt'];
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }
    if (value is int) {
      return value;
    }
    return 0;
  }

  static String _text(Object? value, {required String fallback}) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;

  static String? _optText(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
}

/// Ligne d'un morceau récent.
class _RecentTrackTile extends StatelessWidget {
  const _RecentTrackTile({
    required this.title,
    required this.album,
    required this.artistId,
    required this.when,
    required this.isLast,
  });

  final String title;
  final String album;
  final String? artistId;
  final int when;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String subtitle = <String>[
      album,
      if (artistId != null) adminArtistName(artistId!),
      _relative(when),
    ].where((String s) => s.isNotEmpty).join(' · ');

    return Column(
      children: <Widget>[
        ListTile(
          leading: CircleAvatar(
            backgroundColor: colors.primary.withValues(alpha: 0.15),
            foregroundColor: colors.primary,
            child: const Icon(Icons.music_note, size: 20),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (!isLast)
          Divider(
              height: 1, color: colors.outlineVariant.withValues(alpha: 0.4)),
      ],
    );
  }

  /// Libellé relatif simple (« aujourd'hui », « il y a N j »).
  static String _relative(int millis) {
    if (millis == 0) {
      return '';
    }
    final Duration diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(millis),
    );
    if (diff.inDays == 0) {
      return 'aujourd\'hui';
    }
    if (diff.inDays < 31) {
      return 'il y a ${diff.inDays} j';
    }
    return 'il y a ${(diff.inDays / 30).floor()} mois';
  }
}

/// Mini-liste des derniers articles merchandise (5 maximum).
class _RecentMerch extends StatelessWidget {
  const _RecentMerch({required this.docs});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  @override
  Widget build(BuildContext context) {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> sorted =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.of(docs)
          ..sort(
            (
              QueryDocumentSnapshot<Map<String, dynamic>> a,
              QueryDocumentSnapshot<Map<String, dynamic>> b,
            ) =>
                _readMillis(b.data()).compareTo(_readMillis(a.data())),
          );
    final items = sorted.take(5).toList();

    if (items.isEmpty) {
      return const _EmptyHint(
        message: 'Aucun article merchandise pour ce périmètre.',
      );
    }

    final ThemeData theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < items.length; i++)
            _RecentMerchTile(
              name: _text(items[i].data()['name'], fallback: 'Article'),
              price: items[i].data()['price_fcfa'],
              artistId: _optText(items[i].data()['artistId']),
              when: _readMillis(items[i].data()),
              isLast: i == items.length - 1,
            ),
        ],
      ),
    );
  }

  static int _readMillis(Map<String, dynamic> data) {
    final Object? value = data['created_at'] ?? data['createdAt'];
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }
    if (value is int) {
      return value;
    }
    return 0;
  }

  static String _text(Object? value, {required String fallback}) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;

  static String? _optText(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
}

/// Ligne d'un article merchandise récent.
class _RecentMerchTile extends StatelessWidget {
  const _RecentMerchTile({
    required this.name,
    required this.price,
    required this.artistId,
    required this.when,
    required this.isLast,
  });

  final String name;
  final Object? price;
  final String? artistId;
  final int when;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String priceLabel =
        price is num ? '${(price! as num).round()} FCFA' : '';
    final String subtitle = <String>[
      if (priceLabel.isNotEmpty) priceLabel,
      if (artistId != null) adminArtistName(artistId!),
      _relative(when),
    ].where((String s) => s.isNotEmpty).join(' · ');

    return Column(
      children: <Widget>[
        ListTile(
          leading: CircleAvatar(
            backgroundColor: colors.tertiary.withValues(alpha: 0.15),
            foregroundColor: colors.tertiary,
            child: const Icon(Icons.checkroom, size: 20),
          ),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.4),
          ),
      ],
    );
  }

  static String _relative(int millis) {
    if (millis == 0) {
      return '';
    }
    final Duration diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(millis),
    );
    if (diff.inDays == 0) {
      return 'aujourd\'hui';
    }
    if (diff.inDays < 31) {
      return 'il y a ${diff.inDays} j';
    }
    return 'il y a ${(diff.inDays / 30).floor()} mois';
  }
}

/// Message d'état vide d'une mini-liste.
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Message d'erreur de flux Firestore.
class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool indexPending = isMissingFirestoreIndex(error);
    final String message = indexPending
        ? 'Index Firestore en cours de création. Déployez-les avec '
            '« firebase deploy --only firestore:indexes », puis rechargez.'
        : 'Impossible de charger les statistiques.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, color: colors.error),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Boutons d'accès direct aux écrans de publication.
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onUpload,
    required this.onMerch,
    required this.onEvent,
  });

  final VoidCallback onUpload;
  final VoidCallback onMerch;
  final VoidCallback onEvent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _QuickAction(
          icon: Icons.cloud_upload_outlined,
          label: 'Uploader un morceau',
          color: const Color(0xFF8B5CF6),
          onTap: onUpload,
        ),
        _QuickAction(
          icon: Icons.add_shopping_cart_outlined,
          label: 'Ajouter un produit',
          color: const Color(0xFFF59E0B),
          onTap: onMerch,
        ),
        _QuickAction(
          icon: Icons.event_available_outlined,
          label: 'Planifier un événement',
          color: const Color(0xFF10B981),
          onTap: onEvent,
        ),
      ],
    );
  }
}

/// Un bouton d'action rapide.
class _QuickAction extends StatefulWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: _hovered
            ? (Matrix4.identity()..translateByDouble(0, -3, 0, 1))
            : Matrix4.identity(),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            side: BorderSide(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.7)
                  : Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          icon: Icon(widget.icon, color: widget.color),
          label: Text(widget.label),
          onPressed: widget.onTap,
        ),
      ),
    );
  }
}

/// Squelette de chargement du tableau de bord (KPI + graphique).
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(child: CircularProgressIndicator()),
        SizedBox(height: 24),
        Row(
          children: <Widget>[
            Expanded(child: _SkeletonBox(height: 150)),
            SizedBox(width: 16),
            Expanded(child: _SkeletonBox(height: 150)),
            SizedBox(width: 16),
            Expanded(child: _SkeletonBox(height: 150)),
            SizedBox(width: 16),
            Expanded(child: _SkeletonBox(height: 150)),
          ],
        ),
        SizedBox(height: 16),
        _SkeletonBox(height: 200),
      ],
    );
  }
}

/// Squelette de chargement d'une mini-liste.
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        _SkeletonBox(height: 64),
        SizedBox(height: 8),
        _SkeletonBox(height: 64),
        SizedBox(height: 8),
        _SkeletonBox(height: 64),
      ],
    );
  }
}

/// Bloc gris arrondi, placeholder de contenu en cours de chargement.
class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
