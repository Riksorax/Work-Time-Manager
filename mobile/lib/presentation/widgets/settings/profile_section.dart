import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileSection extends StatelessWidget {
  final User user;
  const ProfileSection({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage:
                  user.photoURL != null ? NetworkImage(user.photoURL!) : null,
              child: user.photoURL == null
                  ? Icon(Icons.person,
                      size: 24, color: theme.colorScheme.onSurfaceVariant)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                user.displayName ?? 'No name',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
