import 'package:shared_preferences/shared_preferences.dart';

/// Local, on-device record of whether this install has already been shown
/// the onboarding slides.
///
/// Onboarding is a first-run explainer, not a splash screen: it must appear
/// exactly once per install, never again after the user finishes or skips
/// it - not on the next app open, and not after a later logout/login. The
/// router's `redirect` reads [hasCompletedOnboarding] before ever showing
/// `/onboarding`, and `OnboardingScreen` calls [markOnboardingComplete] on
/// every exit path (Skip, the top-bar skip pill, and "Get Started").
const _kOnboardingCompleteKey = 'onboarding_complete';

Future<bool> hasCompletedOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingCompleteKey) ?? false;
}

Future<void> markOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingCompleteKey, true);
}
