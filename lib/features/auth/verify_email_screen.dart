import 'package:flutter/material.dart';

import '../profile/account_screen.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) => const ProfileScreen(focusVerification: true);
}
