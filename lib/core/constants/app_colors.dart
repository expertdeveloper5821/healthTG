import 'package:flutter/material.dart';

class AppColors {

  static const Color background = Color(0xFF161819);
  static const Color backgroundright = Color(0xFF1E2021);


//unselected Color
    static const Color unselected = Color(0XFF878B93);

//Location Icon
    static const Color location = Color(0xFFCBD3D1);
  //
  static const Color text = Color(0xFFA2A3A3);
  static const Color deepOcean = Color(0xFF00486A);
  static const Color cardGradientStart = Color(0xFF97DAFA);
  static const Color cardGradientEnd = Color(0xFF43C3FF);


  static const Color white = Colors.white;
  static const Color grey = Colors.grey;
  static const Color black = Colors.black;


  static const Color textPrimary = white;
  static const Color textSecondary = Colors.grey;


  static const LinearGradient blueCardGradient = LinearGradient( 
    colors: [
         cardGradientEnd,
      cardGradientStart,
   
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}