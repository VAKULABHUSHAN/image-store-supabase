import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'imageget.dart';
import 'profile_page.dart';
import 'standby_screen.dart';

class MainNavigationShell extends StatefulWidget {
  final int initialIndex;

  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _updateOrientationForTab(_currentIndex);
  }

  void _updateOrientationForTab(int index) {
    if (index == 2) {
      // 🔄 Force Landscape when entering Standby mode
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      // 🔄 Restore Portrait for Home, Gallery, and Profile tabs
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
    _updateOrientationForTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF14141E) : Colors.white;
    final navBorder = isDark ? Colors.white12 : Colors.black12;

    Widget body;
    switch (_currentIndex) {
      case 0:
        body = const UploadPage();
        break;
      case 1:
        body = const ImageGalleryPage();
        break;
      case 2:
        body = StandbyScreen(
          onExit: () => _onTabTapped(0),
        );
        break;
      case 3:
        body = const ProfileScreen();
        break;
      default:
        body = const UploadPage();
    }

    // Hide bottom navigation bar in Standby mode for a pure immersive landscape experience
    final showBottomNav = _currentIndex != 2;

    return Scaffold(
      body: body,
      bottomNavigationBar: showBottomNav
          ? Container(
              decoration: BoxDecoration(
                color: navBg,
                border: Border(top: BorderSide(color: navBorder, width: 0.5)),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, -3),
                        ),
                      ],
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: _onTabTapped,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: const Color(0xFF6C63FF),
                unselectedItemColor: isDark ? Colors.white54 : const Color(0xFF777788),
                selectedFontSize: 12,
                unselectedFontSize: 12,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_rounded),
                    activeIcon: Icon(Icons.home_rounded, size: 26),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.photo_library_rounded),
                    activeIcon: Icon(Icons.photo_library_rounded, size: 26),
                    label: 'Gallery',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.graphic_eq_rounded),
                    activeIcon: Icon(Icons.graphic_eq_rounded, size: 26),
                    label: 'Standby',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_rounded),
                    activeIcon: Icon(Icons.person_rounded, size: 26),
                    label: 'Profile',
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
