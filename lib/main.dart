import 'dart:async';

import 'package:flutter/foundation.dart'
    show FlutterError, TargetPlatform, defaultTargetPlatform, kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/routing/app_router.dart';
import 'theme/app_theme.dart';

/// ─── Configuration ──────────────────────────────────────────────────────────
///
/// Supplied at build time so staging and production can point at different
/// Supabase projects without editing source:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ... \
///     --dart-define=AGORA_APP_ID=... \
///     --dart-define=GROQ_API_KEY=...
///
/// The defaults are the existing development project, so an unconfigured
/// `flutter run` still works exactly as before.
///
/// The anon key is a public, row-level-security-scoped credential and is meant
/// to ship in the client. The service-role key must never appear here.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://eyycsflzqrueqnllgrvk.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6'
        'ImV5eWNzZmx6cXJ1ZXFubGxncnZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzODYx'
        'NDQsImV4cCI6MjA4Nzk2MjE0NH0.'
        'ayH7lXE7Kh-H2KHxM2WFSTPjNhC3wcktEg0zHjGHbR4',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

/// True in a browser or a resizable desktop window, where the viewport can be
/// arbitrarily wide. False on native Android/iOS - including tablets - where
/// the app should fill the real screen.
bool get _isWideWindowPlatform =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

Future<void> main() async {
  // Catching errors from the whole zone - including async ones raised outside
  // a widget build - so a release build reports rather than silently dies.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // In release, never show the red error screen; show something a patient
      // can act on instead.
      if (kReleaseMode) {
        ErrorWidget.builder = (details) => const Directionality(
          textDirection: TextDirection.ltr,
          child: _FatalErrorScreen(),
        );
      }
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('Uncaught Flutter error: ${details.exception}');
      };

      // Dark status-bar glyphs over the light page background.
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      );

      String? startupError;
      try {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseAnonKey,
        );
      } catch (e) {
        // A failed backend handshake must not leave the user on a black
        // screen with no explanation.
        debugPrint('Supabase initialisation failed: $e');
        startupError =
            'We could not reach the SomaCare servers. Check your internet '
            'connection and reopen the app.';
      }

      runApp(
        ProviderScope(child: SomaCareApp(startupError: startupError)),
      );
    },
    (error, stack) => debugPrint('Uncaught zone error: $error\n$stack'),
  );
}

class SomaCareApp extends StatelessWidget {
  const SomaCareApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    if (startupError != null) {
      return MaterialApp(
        title: 'SomaCare',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: _FatalErrorScreen(message: startupError),
      );
    }

    return MaterialApp.router(
      title: 'SomaCare',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      // One theme, honestly declared. The app was previously served a
      // `Brightness.dark` ThemeData filled with light colours, which made
      // Flutter's own widgets choose dark-theme defaults on a white page.
      theme: buildAppTheme(),
      themeMode: ThemeMode.light,
      builder: (context, child) {
        final media = MediaQuery.of(context);

        // Respect the user's font-size preference, but stop runaway scaling
        // (Android allows up to 2.0x) from bursting fixed-height cards.
        final scaled = MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.4,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );

        // SomaCare is a phone-shaped design. On a wide browser or desktop
        // window, letterbox it instead of stretching every grid.
        if (!_isWideWindowPlatform) return scaled;
        return ColoredBox(
          color: AppColors.surfaceMuted,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: scaled,
            ),
          ),
        );
      },
    );
  }
}

/// Shown when the app cannot start, or when a widget throws in release.
class _FatalErrorScreen extends StatelessWidget {
  const _FatalErrorScreen({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.errorWash,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    color: AppColors.error,
                    size: 30,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'SomaCare could not start',
                  textAlign: TextAlign.center,
                  style: BloomTextStyles.fraunces(
                    size: AppTypography.headlineMedium,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message ??
                      'Something went wrong on this screen. Close the app and '
                          'open it again.',
                  textAlign: TextAlign.center,
                  style: BloomTextStyles.inter(
                    size: AppTypography.bodyLarge,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
