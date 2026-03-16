import 'dart:math';
import 'package:flutter/material.dart';
import 'slider_captcha.dart';
import 'math_captcha.dart';
import 'tap_captcha.dart';

class HumanVerificationScreen extends StatelessWidget {
  const HumanVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final random = Random().nextInt(3);

    Widget captcha;

    if (random == 0) {
      captcha = const SliderCaptcha();
    } else if (random == 1) {
      captcha = const MathCaptcha();
    } else {
      captcha = const TapCaptcha();
    }

    return captcha;
  }
}