import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/api_config.dart';
import '../providers/api_config_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _customModelController = TextEditingController();
  ApiProvider? _selectedProvider;
  bool _obscureKey = true;
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  void _startEditing(ApiConfig config) {
    setState(() {
      _editing = true;
      _selectedProvider = config.provider;
      _apiKeyController.text = config.apiKey;
      _customModelController.text = config.model ?? '';
    });
  }

  Future<void> _saveConfig() async {
    if (_apiKeyController.text.trim().isEmpty) return;

    setState(() => _saving = true);

    final config = ApiConfig(
      provider: _selectedProvider ?? ApiProvider.openai,
      apiKey: _apiKeyController.text.trim(),
      model: _customModelController.text.trim(),
    );

    await ref.read(apiConfigProvider.notifier).saveConfig(config);

    if (mounted) {
      setState(() {
        _saving = false;
        _editing = false;
      });
    }
  }

  Future<void> _clearConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear API Key?'),
        content: const Text(
          'This will remove your stored API key. You will need to enter it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(apiConfigProvider.notifier).clearConfig();
      if (mounted) {
        context.go('/setup');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(apiConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (config) {
          if (config == null) {
            return const Center(child: Text('No API key configured.'));
          }

          if (_editing) {
            return _buildEditForm(config);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                title: const Text('Provider'),
                subtitle: Text(config.provider.displayName),
              ),
              if (config.provider == ApiProvider.openrouter &&
                  config.model != null &&
                  config.model!.isNotEmpty)
                ListTile(
                  title: const Text('Model'),
                  subtitle: Text(config.model!),
                ),
              ListTile(
                title: const Text('API Key'),
                subtitle: Text(
                  '••••••••${config.apiKey.length > 4 ? config.apiKey.substring(config.apiKey.length - 4) : ''}',
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Change API Key'),
                onTap: () => _startEditing(config),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Clear API Key',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: _clearConfig,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEditForm(ApiConfig? currentConfig) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<ApiProvider>(
            initialValue: _selectedProvider,
            decoration: const InputDecoration(
              labelText: 'Provider',
              border: OutlineInputBorder(),
            ),
            items: ApiProvider.values.map((provider) {
              return DropdownMenuItem(
                value: provider,
                child: Text(provider.displayName),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedProvider = value);
              }
            },
          ),
          if (_selectedProvider == ApiProvider.openrouter) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _customModelController,
              decoration: const InputDecoration(
                labelText: 'Model string (Optional)',
                hintText: 'e.g. openrouter/healer-alpha',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _apiKeyController,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: 'API Key',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureKey ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => _obscureKey = !_obscureKey);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _editing = false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveConfig,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
