import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme.dart';
import 'screens/swipe_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Disable HTTP font fetching to avoid ClientException on devices without internet
  GoogleFonts.config.allowRuntimeFetching = false;

  runApp(
    const ProviderScope(
      child: SwipixApp(),
    ),
  );
}

class SwipixApp extends StatelessWidget {
  const SwipixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swipix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.masterTheme,
      home: const SwipeScreen(),
    );
  }
}
