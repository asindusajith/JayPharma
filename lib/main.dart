import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const JayPharmaApp(),
    ),
  );
}

class JayPharmaApp extends StatelessWidget {
  const JayPharmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => appState.userInteracted(),
          child: MaterialApp(
            title: 'Jay Pharma',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(),
            home: appState.isLoggedIn ? const HomeScreen() : const LoginScreen(),
          ),
        );
      },
    );
  }
}
