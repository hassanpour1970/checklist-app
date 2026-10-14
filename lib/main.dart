import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'services/db.dart';
import 'screens/home_screen.dart';
import 'screens/saved_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await DB.init();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fa')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      title: 'app_name'.tr(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _pages = const [
    HomeScreen(),
    SavedScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: const Icon(Icons.folder),
            label: 'groups'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.save_outlined),
            selectedIcon: const Icon(Icons.save),
            label: 'filled'.tr(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final isFa = context.locale.languageCode == 'fa';
          context.setLocale(isFa ? const Locale('en') : const Locale('fa'));
        },
        icon: const Icon(Icons.language),
        label: Text('language'.tr()),
      ),
    );
  }
}
