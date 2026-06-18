import 'package:flutter/material.dart';

/// Wrapper — just pass onPreferencesSaved to CareerPreferencesScreen
/// after you add the optional parameter to it (see instructions above).
class CareerPreferencesScreenForJobMatching extends StatelessWidget {
  final VoidCallback onPreferencesSaved;

  const CareerPreferencesScreenForJobMatching({
    super.key,
    required this.onPreferencesSaved,
  });

  @override
  Widget build(BuildContext context) {
    // Once you add `onPreferencesSaved` parameter to CareerPreferencesScreen:
    // return CareerPreferencesScreen(onPreferencesSaved: onPreferencesSaved);
    //
    // For now, just return the screen as-is:
    // The user can still save and we'll navigate afterward.
    return const Placeholder(); // ← replace with CareerPreferencesScreen(onPreferencesSaved: onPreferencesSaved)
  }
}
