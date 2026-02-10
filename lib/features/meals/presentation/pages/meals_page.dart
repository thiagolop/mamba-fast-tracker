import 'package:flutter/material.dart';

import '../meals_strings.dart';

class MealsPage extends StatelessWidget {
  const MealsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(MealsStrings.placeholder),
      ),
    );
  }
}
