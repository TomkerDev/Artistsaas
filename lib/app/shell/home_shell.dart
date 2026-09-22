import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../features/catalog/presentation/home_screen.dart';
import '../../features/library/presentation/my_music_screen.dart';
import '../../features/player/presentation/player_screen.dart';
import 'mini_player.dart';

/// Onglet sélectionné, partagé entre la coquille et le mini-lecteur.
final ValueNotifier<int> selectedTabNotifier = ValueNotifier<int>(0);

/// Coquille principale de l'application : barre d'onglets et contenu des trois
/// écrans du MVP.
///
/// Les écrans sont conservés dans un `IndexedStack` afin de préserver leur état
/// (position de défilement du catalogue, onglet du lecteur) lors du changement
/// d'onglet. Le mini-lecteur persistant s'insère ici, entre le contenu et la
/// barre d'onglets.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const List<Widget> _screens = <Widget>[
    HomeScreen(),
    PlayerScreen(),
    MyMusicScreen(),
  ];

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    selectedTabNotifier.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    selectedTabNotifier.removeListener(_onTabRequested);
    super.dispose();
  }

  /// Demande de navigation venant du mini-lecteur.
  void _onTabRequested() {
    final int requested = selectedTabNotifier.value;
    if (requested != _selectedIndex) {
      setState(() => _selectedIndex = requested);
    }
  }

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) {
      return;
    }
    selectedTabNotifier.value = index;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: _screens),
          ),
          // Le mini-lecteur est masqué sur l'onglet Lecteur : le lecteur complet
          // joue déjà ce rôle, un doublon visuel serait redondant.
          if (_selectedIndex != 1) const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: AppStrings.tabHome,
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: AppStrings.tabPlayer,
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: AppStrings.tabMyMusic,
          ),
        ],
      ),
    );
  }
}
