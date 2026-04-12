import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/domain/auth_notifier.dart';
import '../../../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  child: Text(
                    user?.email?.substring(0, 1).toUpperCase() ?? '?',
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.email ?? '—',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _Section(title: 'Meine Autos', children: [
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: const Text('Auto einstellen'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 16),
          _Section(title: 'Buchungen', children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Meine Buchungen'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 16),
          _Section(title: 'Fahrer', children: [
            ListTile(
              leading: const Icon(Icons.person_pin_circle),
              title: const Text('Als Fahrer anbieten'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 16),
          _Section(title: 'Konto', children: [
            ListTile(
              leading: const Icon(Icons.verified_user),
              title: const Text('Führerschein verifizieren'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('Zahlungsmethoden'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Colors.grey),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}
