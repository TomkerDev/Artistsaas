import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';

/// Écran du lecteur : lecture du morceau en cours.
///
/// Étape 0 : coquille vide. Le lecteur (pochette, barre de progression, contrôles
/// précédent/suivant, file de lecture) est implémenté à l'étape 3 via un
/// `PlaybackController` alimenté par `AudioPlayerService`.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.playerTitle)),
      body: const _PlayerPlaceholder(),
    );
  }
}

class _PlayerPlaceholder extends StatelessWidget {
  const _PlayerPlaceholder();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.graphic_eq, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              AppStrings.playerPlaceholder,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
