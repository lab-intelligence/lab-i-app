import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/api_config.dart';
import '../providers/api_config_provider.dart';

class ApiKeySetupScreen extends ConsumerStatefulWidget {
  const ApiKeySetupScreen({super.key});

  @override
  ConsumerState<ApiKeySetupScreen> createState() => _ApiKeySetupScreenState();
}

class _ApiKeySetupScreenState extends ConsumerState<ApiKeySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  final _customModelController = TextEditingController();
  ApiProvider _selectedProvider = ApiProvider.openai;
  bool _obscureKey = true;
  bool _saving = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final config = ApiConfig(
      provider: _selectedProvider,
      apiKey: _apiKeyController.text.trim(),
      model: _customModelController.text.trim(),
    );

    await ref.read(apiConfigProvider.notifier).saveConfig(config);

    if (mounted) {
      setState(() => _saving = false);
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Key Setup')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Configure your AI provider to get started with image classification.',
              ),
              const SizedBox(height: 24),
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your API key';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _saveConfig,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save & Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
