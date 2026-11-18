import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final store = StorageService.instance;
  late final _key = TextEditingController(text: store.apiKey ?? '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Clé API Claude (pour la lecture du tableau)'),
        TextField(controller: _key, obscureText: true,
            decoration: const InputDecoration(hintText: 'sk-ant-...')),
        const SizedBox(height: 8),
        FilledButton(onPressed: () async {
          await store.setApiKey(_key.text.trim());
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Clé enregistrée')));
        }, child: const Text('Enregistrer la clé')),
        const Divider(height: 40),
        const Text('Confidentialité', style: TextStyle(fontWeight: FontWeight.bold)),
        const Text('Toutes tes données restent sur ce téléphone. '
            'Les photos du tableau sont envoyées à l\'IA pour lecture. Les photos prises par l\'appli sont ensuite supprimées ; celles de ta galerie ne sont pas touchées. '
            'La montre : seules la durée et les calories sont lues, jamais la fréquence cardiaque.'),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_forever),
          label: const Text('Supprimer toutes mes données'),
          onPressed: () async {
            await store.wipeAll();
            _key.clear();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Données supprimées')));
          },
        ),
      ]),
    );
  }
}
