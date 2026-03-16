import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/api_config.dart';
import '../providers/api_config_provider.dart';
import '../providers/theme_provider.dart';

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
    final isOllama = _selectedProvider == ApiProvider.ollama;
    if (!isOllama && _apiKeyController.text.trim().isEmpty) return;

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

          final themeModeAsync = ref.watch(themeModeProvider);
          final themeMode = themeModeAsync.valueOrNull ?? ThemeMode.system;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionHeader(title: 'Appearance'),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.palette_outlined),
                        title: Text('Theme Mode'),
                        subtitle: Text('Switch between light and dark themes'),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.system,
                                label: Text('Auto'),
                                icon: Icon(Icons.brightness_auto_outlined),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                label: Text('Light'),
                                icon: Icon(Icons.light_mode_outlined),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                label: Text('Dark'),
                                icon: Icon(Icons.dark_mode_outlined),
                              ),
                            ],
                            selected: {themeMode},
                            onSelectionChanged: (newSelection) {
                              ref
                                  .read(themeModeProvider.notifier)
                                  .setThemeMode(newSelection.first);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'API Configuration'),
              const SizedBox(height: 8),
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
              if (config.provider != ApiProvider.ollama)
                ListTile(
                  title: const Text('API Key'),
                  subtitle: Text(
                    '••••••••${config.apiKey.length > 4 ? config.apiKey.substring(config.apiKey.length - 4) : ''}',
                  ),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
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
          if (_selectedProvider == ApiProvider.openrouter ||
              _selectedProvider == ApiProvider.ollama) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _customModelController,
              decoration: InputDecoration(
                labelText: _selectedProvider == ApiProvider.ollama
                    ? 'Ollama Model'
                    : 'Model string (Optional)',
                hintText: _selectedProvider == ApiProvider.ollama
                    ? 'e.g. llava'
                    : 'e.g. openrouter/healer-alpha',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_selectedProvider != ApiProvider.ollama)
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
          if (_selectedProvider == ApiProvider.ollama)
            const Card(
              color: Colors.blueGrey,
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  "Ollama runs locally on your device. No API key needed.\nMake sure Ollama is installed and running before classifying.",
                  style: TextStyle(color: Colors.white, fontSize: 13),
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

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
