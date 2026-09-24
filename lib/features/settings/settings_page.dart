import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app/theme.dart';
import '../../core/logging/cosy_logger.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../providers/app_providers.dart';
import '../../widgets/gradient_button.dart';

/// 设置页：服务地址 / API Key / 连通性测试，分组卡片。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  bool _mockEnabled = false;
  String? _testResult;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await ref.read(settingsProvider.future);
    if (!mounted) return;
    _baseUrl.text = settings.baseUrl;
    _apiKey.text = settings.apiKey;
    _mockEnabled = settings.mockEnabled;
    setState(() {});
  }

  Future<void> _save() async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'cosy.baseUrl', value: _baseUrl.text.trim());
    if (_apiKey.text.trim().isNotEmpty) {
      await storage.write(key: 'cosy.apiKey', value: _apiKey.text.trim());
    } else {
      await storage.delete(key: 'cosy.apiKey');
    }
    CosyLogger.instance.info('cfg',
        '保存配置: baseUrl=${_baseUrl.text.trim()} apiKey=${_apiKey.text.trim().isEmpty ? '未设置' : '已设置'} mock=$_mockEnabled');
    ref.invalidate(settingsProvider);
    ref.invalidate(apiClientProvider);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('配置已保存')));
    }
  }

  /// Mock 开关即时生效：切换即持久化并重建网络层（不依赖"保存配置"按钮）。
  Future<void> _toggleMock(bool value) async {
    setState(() => _mockEnabled = value);
    const storage = FlutterSecureStorage();
    await storage.write(key: 'cosy.mockEnabled', value: value.toString());
    CosyLogger.instance.info('cfg', 'Mock 开关: $value');
    ref.invalidate(settingsProvider);
    ref.invalidate(apiClientProvider);
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
    final theme = Theme.of(context);
    final success = _testResult?.startsWith('连接成功') ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('服务连接',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _baseUrl,
                        decoration: const InputDecoration(
                          labelText: '服务地址',
                          hintText: 'http://localhost:28080',
                          helperText: '移动端真机请填局域网/线上地址',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _apiKey,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'API Key（X-API-Key，可选）',
                          helperText: '服务端配置 COSY_AGENT_API_KEY 后必填',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          GradientButton(
                            label: '保存配置',
                            icon: Icons.save_outlined,
                            onPressed: _save,
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: _testing ? null : _test,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMd),
                              ),
                            ),
                            child: Text(_testing ? '测试中…' : '测试连接'),
                          ),
                        ],
                      ),
                      if (_testResult != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: (success
                                      ? Colors.green
                                      : theme.colorScheme.error)
                                  .withValues(alpha: 0.10),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: Text(
                              _testResult!,
                              style: TextStyle(
                                fontSize: 12,
                                color: success
                                    ? Colors.green.shade400
                                    : theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('运行模式',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mock 模式'),
                        subtitle: const Text(
                            '开启后所有对话请求携带 X-Cosy-Mock: true，'
                            '由服务端模拟 LLM 全链路（无需真实模型 Key）；'
                            '关闭时不携带该请求头，回退服务端全局配置'),
                        value: _mockEnabled,
                        onChanged: _toggleMock,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('说明',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      Text(
                        '· Mock 模式：客户端开关（请求级 X-Cosy-Mock）或服务端 '
                        'COSY_AGENT_MOCK_ENABLED=true 均可无 Key 演示全链路\n'
                        '· 鉴权：配置 API Key 后所有 /api/** 请求自动携带 X-API-Key\n'
                        '· 401 时请回本页核对 Key 与服务地址',
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
