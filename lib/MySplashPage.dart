import 'package:ar_object_indentification/HomePage.dart';
import 'package:flutter/material.dart';
import 'package:another_flutter_splash_screen/another_flutter_splash_screen.dart';


class MySplashPage extends StatefulWidget {
  const MySplashPage({super.key});

  @override
  _MySplashPageState createState() => _MySplashPageState();
}

class _MySplashPageState extends State<MySplashPage> {
  @override
  Widget build(BuildContext context) {
    return FlutterSplashScreen.fadeIn(
      backgroundColor: Colors.white,
      onInit: () {
        debugPrint("On Init");
      },
      onEnd: () {
        debugPrint("On End");
      },
      childWidget: SizedBox(
        height: 200,
        width: 200,
        child: Image.asset("assets/Splash_Screen_Icon.png"),
      ),
      onAnimationEnd: () => debugPrint("On Fade In End"),
      nextScreen: const HomePage(),
        duration: const Duration(milliseconds: 3515)
    );
  }
}

