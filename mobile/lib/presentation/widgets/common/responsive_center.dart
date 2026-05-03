import 'package:flutter/material.dart';

/// A wrapper widget that centers its child and constrains its width
/// on larger screens (web/tablet/desktop).
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxContentWidth;
  final EdgeInsetsGeometry padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxContentWidth = 800.0, // Default max width for content like dashboard/forms
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
