import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';

/// Écran « Ma musique » : morceaux disponibles hors connexion.
///
/// Étape 0 : coquille vide. La liste des morceaux téléchargés (lecture depuis le
/// stockage local, progression et suppression) est implémentée à l'étape 4 via un
/// `DownloadsController` alimenté par `DownloadRepository`.
class MyMusicScreen extends StatelessWidget {
  const MyMusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.myMusicTitle)),
      body: const _MyMusicPlaceholder(),
    );
  }
}

class _MyMusicPlaceholder extends StatelessWidget {
  const _MyMusicPlaceholder();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.folder_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.myMusicPlaceholder,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
