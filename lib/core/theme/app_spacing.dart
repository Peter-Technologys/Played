import 'package:flutter/material.dart';

abstract class AppSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;

  static const Widget vXs  = SizedBox(height: xs);
  static const Widget vSm  = SizedBox(height: sm);
  static const Widget vMd  = SizedBox(height: md);
  static const Widget vLg  = SizedBox(height: lg);
  static const Widget vXl  = SizedBox(height: xl);
  static const Widget vXxl = SizedBox(height: xxl);

  static const Widget hXs  = SizedBox(width: xs);
  static const Widget hSm  = SizedBox(width: sm);
  static const Widget hMd  = SizedBox(width: md);
  static const Widget hLg  = SizedBox(width: lg);
  static const Widget hXl  = SizedBox(width: xl);

  static const EdgeInsets screenPadding   = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets cardPadding     = EdgeInsets.all(md);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(horizontal: md, vertical: sm);
}
