import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mapfav/firebase_options.dart';
import 'package:mapfav/screens/mapScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const assignment7());
}

//***************************************//
//Troubled using emulator not showing map
//used a physical device it works
//***************************************//

class assignment7 extends StatelessWidget {
  const assignment7({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: mapScreen(),
    );
  }
}
