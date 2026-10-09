import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth.dart';
import '../../core/brand.dart';
import '../../core/locale.dart';
import '../feedback/feedback_button.dart';
import '../feedback/feedback_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final _name = TextEditingController(text: ref.read(authProvider).value?.name);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).updateName(_name.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(messagesProvider).saved)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final t = ref.watch(messagesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.profile)),
      bottomNavigationBar: const PleasanceFooter(),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(user?.email ?? '', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            maxLength: 255,
            decoration: InputDecoration(labelText: t.name),
            onSubmitted: (_) => _save(),
          ),
          FilledButton(onPressed: _busy ? null : _save, child: Text(t.save)),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () => showFeedbackSheet(context, ref, FeedbackKind.idea),
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(t.giveFeedback),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.testMode),
            subtitle: Text(t.testModeHint),
            value: ref.watch(testModeProvider).value ?? false,
            onChanged: (on) => ref.read(testModeProvider.notifier).set(on),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            child: Text(t.logOut),
          ),
        ],
      ),
    );
  }
}
