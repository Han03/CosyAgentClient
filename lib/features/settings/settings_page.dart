import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../providers/app_providers.dart';

/// 设置页：服务地址 / API Key / 连通性测试。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  String? _testResult;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await ref.read(settingsProvider.future);
    _baseUrl.text = settings.baseUrl;
    _apiKey.text = settings.apiKey;
  }

  Future<void> _save() async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'cosy.baseUrl', value: _baseUrl.text.trim());
    if (_apiKey.text.trim().isNotEmpty) {
      await storage.write(key: 'cosy.apiKey', value: _apiKey.text.trim());
    } else {
      await storage.delete(key: 'cosy.apiKey');
    }
    ref.invalidate(settingsProvider);
    ref.invalidate(apiClientProvider);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('配置已保存')));
    }
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final repo = await ref.read(systemRepositoryProvider.future);
      final status = await repo.status();
      final health = await repo.health();
      if (!mounted) return;
      setState(() {
        _testResult =
            '连接成功：step=${status['step']} tools=${status['tools']} health=${health['status']}';
        _testing = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _testResult =
            '连接失败：${e is ApiException ? e.message : e.toString()}';
        _testing = false;
      });
    }
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              labelText: '服务地址',
              hintText: 'http://localhost:8080',
              helperText: '移动端真机请填局域网/线上地址',
            ),
          ),
          TextField(
            controller: _apiKey,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Key（X-API-Key，可选）',
              helperText: '服务端配置 COSY_AGENT_API_KEY 后必填',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: _save,
                child: const Text('保存配置'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _testing ? null : _test,
                child: Text(_testing ? '测试中…' : '测试连接'),
              ),
            ],
          ),
          if (_testResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_testResult!, style: const TextStyle(fontSize: 12)),
            ),
          const Divider(height: 32),
          const Text('提示', style: TextStyle(fontWeight: FontWeight.w600)),
          const Text(
            '· Mock 模式：服务端设 COSY_AGENT_MOCK_ENABLED=true 可无 Key 演示全链路\n'
            '· 鉴权：配置 API Key 后所有 /api/** 请求自动携带 X-API-Key\n'
            '· 401 时请回本页核对 Key 与服务地址',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
