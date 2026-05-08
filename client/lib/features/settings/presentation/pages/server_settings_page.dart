import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/server_config_provider.dart';

class ServerSettingsPage extends ConsumerStatefulWidget {
  const ServerSettingsPage({super.key});

  @override
  ConsumerState<ServerSettingsPage> createState() => _ServerSettingsPageState();
}

class _ServerSettingsPageState extends ConsumerState<ServerSettingsPage> {
  final _baseUrlController = TextEditingController();
  final _socketUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final config = ref.read(serverConfigProvider);
    _baseUrlController.text = config.baseUrl;
    _socketUrlController.text = config.socketUrl;
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _socketUrlController.dispose();
    super.dispose();
  }

  void _saveConfig() {
    if (_formKey.currentState!.validate()) {
      ref.read(serverConfigProvider.notifier).updateConfig(
            baseUrl: _baseUrlController.text,
            socketUrl: _socketUrlController.text,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server settings saved!')),
        );
      }
    }
  }

  void _resetConfig() {
    ref.read(serverConfigProvider.notifier).resetToDefault();
    final config = ref.read(serverConfigProvider);
    _baseUrlController.text = config.baseUrl;
    _socketUrlController.text = config.socketUrl;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        title: const Text('Server Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Base URL',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _baseUrlController,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'http://your-ip:port/api/v1',
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a base URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Socket URL',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _socketUrlController,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'http://your-ip:port',
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a socket URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0095F6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetConfig,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Reset to Default'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
