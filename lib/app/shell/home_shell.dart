import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../features/catalog/presentation/home_screen.dart';
import '../../features/library/presentation/my_music_screen.dart';
import '../../features/player/presentation/player_screen.dart';

/// Coquille principale de l'application : barre d'onglets et contenu des trois
/// écrans du MVP.
///
/// Les écrans sont conservés dans un `IndexedStack` afin de préserver leur état
/// (position de défilement du catalogue, onglet du lecteur) lors du changement
/// d'onglet. Le mini-lecteur persistant viendra s'insérer ici, entre le contenu
/// et la barre d'onglets.
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

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) {
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
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
