import 'package:flutter/material.dart';

class CareerAdvisorApp extends StatelessWidget {
  const CareerAdvisorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('Career Advisor App'))),
    );
  }
}
