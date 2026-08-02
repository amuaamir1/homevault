import 'package:flutter/material.dart';

import '../profile/profile_screen.dart';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen(isInitialSetup: true);
  }
}
