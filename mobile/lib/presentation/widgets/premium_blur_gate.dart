import 'dart:ui';

import 'package:flutter/material.dart';

/// Zeigt [child] hinter einem Blur-Effekt und überlagert ihn mit einem
/// Premium-Kaufanreiz. Wenn [onUpgrade] null ist (z.B. auf Web), wird
/// stattdessen ein Hinweis auf die mobile App angezeigt.
class PremiumBlurGate extends StatelessWidget {
  final Widget child;
  final String featureTitle;
  final String featureText;
  final VoidCallback? onUpgrade;

  const PremiumBlurGate({
    super.key,
    required this.child,
    required this.featureTitle,
    required this.featureText,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(child: child),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: Colors.transparent),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(26),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      size: 56,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    featureTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    featureText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                  const SizedBox(height: 28),
                  if (onUpgrade == null)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Abonnements können derzeit nur in der mobilen App verwaltet werden.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: 260,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: onUpgrade,
                        icon: const Icon(Icons.workspace_premium),
                        label: const Text(
                          'Premium freischalten',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
