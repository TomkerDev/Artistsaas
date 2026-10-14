import 'package:flutter/material.dart';

/// Dialogue d'édition des métadonnées d'un morceau publié.
///
/// Contrairement aux fichiers audio/pochettes (téléversés sur Supabase à la
/// création), l'édition se limite aux **champs texte** : titre, album et URL de
/// la pochette. Remplacer le média lourd reste l'apanage de l'écran d'upload ;
/// ici on corrige les métadonnées sans re-téléverser quoi que ce soit.
///
/// Le résultat est typé via [TrackEditResult] et appliqué à Firestore par
/// l'appelant (collection `tracks`).

/// Champs modifiés d'un morceau, renvoyés par [TrackEditDialog].
@immutable
class TrackEditResult {
  const TrackEditResult({
    required this.id,
    required this.title,
    required this.album,
    required this.coverUrl,
    required this.audioUrl,
  });

  /// Identifiant du document Firestore (`tracks/{id}`).
  final String id;
  final String title;
  final String album;

  /// URL de la pochette ; vide pour conserver l'absence d'image.
  final String coverUrl;

  /// URL du MP3 ; inchangée si laissée vide dans le dialogue.
  final String audioUrl;
}

/// Dialogue d'édition d'un morceau, pré-rempli avec les valeurs courantes.
class TrackEditDialog extends StatefulWidget {
  const TrackEditDialog({
    required this.docId,
    required this.title,
    required this.album,
    required this.coverUrl,
    required this.audioUrl,
    super.key,
  });

  final String docId;
  final String title;
  final String album;
  final String coverUrl;
  final String audioUrl;

  @override
  State<TrackEditDialog> createState() => _TrackEditDialogState();
}

class _TrackEditDialogState extends State<TrackEditDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: widget.title,
  );
  late final TextEditingController _album = TextEditingController(
    text: widget.album,
  );
  late final TextEditingController _cover = TextEditingController(
    text: widget.coverUrl,
  );
  late final TextEditingController _audio = TextEditingController(
    text: widget.audioUrl,
  );

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _title,
      _album,
      _cover,
      _audio,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      TrackEditResult(
        id: widget.docId,
        title: _title.text.trim(),
        album: _album.text.trim(),
        coverUrl: _cover.text.trim(),
        audioUrl: _audio.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le morceau'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Titre'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _album,
                  decoration: const InputDecoration(
                    labelText: 'Album',
                    helperText: 'Facultatif',
                  ),
                ),
                TextFormField(
                  controller: _audio,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'URL audio',
                    helperText:
                        'Le fichier audio ne peut pas être remplacé ici '
                        '(re-publiez le morceau pour changer le MP3).',
                  ),
                ),
                TextFormField(
                  controller: _cover,
                  decoration: const InputDecoration(
                    labelText: 'URL de la pochette',
                    helperText: 'Facultatif',
                  ),
                  validator: _optionalUrl,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
  }

  static String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Champ obligatoire' : null;

  static String? _optionalUrl(String? value) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    return RegExp(r'^https?://').hasMatch(raw)
        ? null
        : 'URL invalide (http:// ou https://)';
  }
}
