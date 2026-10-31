import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'state/game_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = GameState();
  await state.load();
  runApp(ElementAlchemyApp(state: state));
}

class ElementAlchemyApp extends StatelessWidget {
  final GameState state;
  const ElementAlchemyApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Element Alchemy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: HomeShell(state: state),
    );
  }
}
