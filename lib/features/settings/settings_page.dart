import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app/theme.dart';
import '../../core/logging/cosy_logger.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../models/capability_catalog.dart';
import '../../models/model_management.dart';
import '../../providers/app_providers.dart';
import '../../widgets/gradient_button.dart';

/// 设置页（Tab 化）：连接 / 模型管理 / 能力中心 / 日志。
///
/// 模型管理平台化：平台（Provider）→ 模型（ModelSpec）→ 路由规则（Rule）
/// 全部收敛到本页维护；后端为执行权威，Key 加密落库、保存即热更新。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('设置'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '连接'),
              Tab(text: '模型管理'),
              Tab(text: '能力中心'),
              Tab(text: '日志'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ConnectionTab(),
            _ModelManagementTab(),
            _CapabilityTab(),
            _LogTab(),
          ],
        ),
      ),
    );
  }
}

/// 连接 Tab：服务地址 / API Key / 连通性测试 / Mock 开关。
class _ConnectionTab extends ConsumerStatefulWidget {
  const _ConnectionTab();

  @override
  ConsumerState<_ConnectionTab> createState() => _ConnectionTabState();
}

class _ConnectionTabState extends ConsumerState<_ConnectionTab> {
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
      String healthNote = '';
      try {
        final health = await repo.health();
        final s = health['status'] as String? ?? 'UNKNOWN';
        healthNote = s == 'UP'
            ? ' health=UP'
            : '（服务已连接，但依赖未就绪：health=$s，记忆/知识库可能降级）';
      } on Exception {
        healthNote = '（服务已连接，health 查询不可用）';
      }
      if (!mounted) return;
      setState(() {
        _testResult =
            '连接成功：step=${status['step']} tools=${status['tools']}$healthNote';
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
    return Align(
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
          ],
        ),
      ),
    );
  }
}

/// 模型管理 Tab：平台 / 模型 / 路由规则 CRUD + 连通性测试。
class _ModelManagementTab extends ConsumerStatefulWidget {
  const _ModelManagementTab();

  @override
  ConsumerState<_ModelManagementTab> createState() =>
      _ModelManagementTabState();
}

class _ModelManagementTabState extends ConsumerState<_ModelManagementTab> {
  Future<(List<ProviderSummary>, Map<String, List<String>>)>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref
        .read(systemRepositoryProvider.future)
        .then((repo) async {
          final providers = await repo.modelProviders();
          final rules = await repo.modelRules();
          return (providers, rules);
        })
        .catchError((Object e) => (<ProviderSummary>[], <String, List<String>>{}));
    setState(() {});
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      _reload();
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('操作失败：${e is ApiException ? e.message : e}'),
          backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  // ---- 平台 CRUD ----

  Future<void> _showProviderDialog({ProviderSummary? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final baseUrl =
        TextEditingController(text: existing?.baseUrl ?? 'https://');
    final apiKey = TextEditingController();
    final completionsPath = TextEditingController(
        text: existing?.completionsPath ?? '/v1/chat/completions');
    final type = TextEditingController(text: existing?.type ?? 'openai');
    var enabled = existing?.enabled ?? true;
    var timeoutMs = existing?.timeoutMs ?? 60000;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? '新增平台' : '编辑平台'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  enabled: existing == null,
                  decoration: const InputDecoration(
                      labelText: '平台名（唯一标识，如 zhipu）'),
                ),
                TextField(
                  controller: baseUrl,
                  decoration: const InputDecoration(labelText: 'Base URL'),
                ),
                TextField(
                  controller: apiKey,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: existing == null
                        ? 'API Key（必填，加密落库）'
                        : 'API Key（留空保持原值）',
                  ),
                ),
                TextField(
                  controller: completionsPath,
                  decoration:
                      const InputDecoration(labelText: 'Completions Path'),
                ),
                TextField(
                  controller: type,
                  decoration: const InputDecoration(labelText: '类型（默认 openai）'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用'),
                  value: enabled,
                  onChanged: (v) => setDialogState(() => enabled = v ?? true),
                ),
                TextField(
                  controller: TextEditingController(text: timeoutMs.toString()),
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: '超时（毫秒，默认 60000）'),
                  onChanged: (v) => timeoutMs = int.tryParse(v) ?? 60000,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            GradientButton(label: '保存', onPressed: () {
              Navigator.pop(context, true);
            }),
          ],
        ),
      ),
    );
    if (result != true) return;
    final body = <String, dynamic>{
      'baseUrl': baseUrl.text.trim(),
      'completionsPath': completionsPath.text.trim(),
      'type': type.text.trim(),
      'enabled': enabled,
      'timeoutMs': timeoutMs,
    };
    if (apiKey.text.trim().isNotEmpty) {
      body['apiKey'] = apiKey.text.trim();
    }
    await _run(() async {
      final repo = await ref.read(systemRepositoryProvider.future);
      if (existing == null) {
        await repo.createModelProvider(name.text.trim(), body);
      } else {
        await repo.updateModelProvider(existing.name, body);
      }
    });
  }

  Future<void> _deleteProvider(ProviderSummary p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除平台'),
        content: Text('确认删除平台 ${p.name}？被路由规则引用时后端会拒绝。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final repo = await ref.read(systemRepositoryProvider.future);
      await repo.deleteModelProvider(p.name);
    });
  }

  // ---- 模型规格 CRUD ----

  Future<void> _showModelDialog(String provider,
      {ModelSpecInfo? existing}) async {
    final modelId = TextEditingController(text: existing?.modelId ?? '');
    final contextWindow = TextEditingController(
        text: (existing?.contextWindow ?? 0).toString());
    final capabilities = TextEditingController(
        text: existing?.capabilities.join(',') ?? 'chat');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? '新增模型' : '编辑模型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: modelId,
              enabled: existing == null,
              decoration: const InputDecoration(
                  labelText: '模型 ID（如 glm-4-flash）'),
            ),
            TextField(
              controller: contextWindow,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '上下文窗口（tokens）'),
            ),
            TextField(
              controller: capabilities,
              decoration: const InputDecoration(
                  labelText: '能力标签（逗号分隔，如 chat,tools）'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          GradientButton(label: '保存', onPressed: () {
            Navigator.pop(context, true);
          }),
        ],
      ),
    );
    if (result != true) return;
    final body = <String, dynamic>{
      'contextWindow': int.tryParse(contextWindow.text.trim()) ?? 0,
      'capabilities': capabilities.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    };
    await _run(() async {
      final repo = await ref.read(systemRepositoryProvider.future);
      if (existing == null) {
        await repo.addModelSpec(
            provider, modelId.text.trim(), body);
      } else {
        await repo.updateModelSpec(
            provider, existing.modelId, body);
      }
    });
  }

  Future<void> _deleteModel(String provider, ModelSpecInfo m) async {
    await _run(() async {
      final repo = await ref.read(systemRepositoryProvider.future);
      await repo.deleteModelSpec(provider, m.modelId);
    });
  }

  // ---- 路由规则（结构化编辑器：候选引用已登记平台模型） ----

  Future<void> _editRules(Map<String, List<String>> rules) async {
    final repo = await ref.read(systemRepositoryProvider.future);
    List<ProviderSummary> providers;
    try {
      providers = await repo.modelProviders();
    } on Exception {
      providers = const [];
    }
    // 并行拉各平台模型规格（编辑器下拉数据源）
    final modelsByProvider = <String, List<ModelSpecInfo>>{};
    try {
      final details = await Future.wait(
          providers.map((p) => repo.modelProviderDetail(p.name)));
      for (var i = 0; i < providers.length; i++) {
        modelsByProvider[providers[i].name] = details[i].models;
      }
    } on Exception {
      // 降级：编辑器仍可打开，候选下拉仅平台可用
    }
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _RulesEditorPage(
          initialRules: rules,
          providers: providers,
          modelsByProvider: modelsByProvider,
        ),
      ),
    );
    if (saved == true) _reload();
  }

  // ---- 连通性测试 ----

  Future<void> _testProvider(ProviderSummary p) async {
    final repo = await ref.read(systemRepositoryProvider.future);
    ProviderDetail detail;
    try {
      detail = await repo.modelProviderDetail(p.name);
    } on Exception {
      detail = ProviderDetail(
          summary: p, models: const <ModelSpecInfo>[]);
    }
    if (!mounted) return;
    final modelId = TextEditingController();
    final prompt = TextEditingController(text: 'ping');
    String? result;
    var testing = false;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('测试连通：${p.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: null,
                decoration: const InputDecoration(labelText: '模型（留空用平台首个）'),
                items: [
                  for (final m in detail.models)
                    DropdownMenuItem(value: m.modelId, child: Text(m.modelId)),
                ],
                onChanged: (v) => setDialogState(() => modelId.text = v ?? ''),
              ),
              TextField(
                controller: prompt,
                decoration: const InputDecoration(labelText: '测试请求内容'),
              ),
              if (result != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(result!,
                      style: TextStyle(
                          fontSize: 12,
                          color: result!.startsWith('✅')
                              ? Colors.green.shade400
                              : Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭')),
            GradientButton(
              label: testing ? '测试中…' : '开始测试',
              onPressed: testing
                  ? null
                  : () async {
                      setDialogState(() => testing = true);
                      try {
                        final r = await repo.testModelConnection({
                          'providerId': p.name,
                          'modelId': modelId.text.trim(),
                          'prompt': prompt.text.trim(),
                        });
                        final ok = r['ok'] == true;
                        setDialogState(() {
                          result = ok
                              ? '✅ 成功：耗时 ${r['durationMs']}ms\n示例回复：${r['sample'] ?? ''}'
                              : '❌ 失败：${r['error'] ?? '未知错误'}';
                          testing = false;
                        });
                      } on Exception catch (e) {
                        setDialogState(() {
                          result =
                              '❌ 请求失败：${e is ApiException ? e.message : e}';
                          testing = false;
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: FutureBuilder<(List<ProviderSummary>, Map<String, List<String>>)>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                  child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(strokeWidth: 2),
              ));
            }
            final (providers, rules) =
                snap.data ?? (const <ProviderSummary>[], const <String, List<String>>{});
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 路由规则摘要 + 操作
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('路由规则',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _editRules(rules),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('编辑'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (rules.isEmpty)
                          Text('暂无规则。默认 auto 模式使用 default 链；'
                              '候选格式：平台/模型（顺序即降级顺序）',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant))
                        else
                          for (final e in rules.entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Text(
                                '${e.key}: ${e.value.join(' → ')}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Expanded(
                              child: Text('模型平台',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                            ),
                            GradientButton(
                              label: '添加平台',
                              icon: Icons.add,
                              onPressed: () => _showProviderDialog(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('平台 Key 加密落库、仅掩码回显；保存即热更新',
                            style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (providers.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('暂无平台。点击"添加平台"登记模型供应商',
                            style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    ),
                  )
                else
                  for (final p in providers)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: (p.enabled
                                    ? Colors.blue
                                    : theme.colorScheme.onSurfaceVariant)
                                .withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          child: Icon(
                            p.enabled
                                ? Icons.cloud_outlined
                                : Icons.cloud_off_outlined,
                            size: 18,
                            color: p.enabled
                                ? Colors.blue.shade400
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(p.name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Text(
                              p.enabled ? '启用' : '停用',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: p.enabled
                                      ? Colors.green.shade400
                                      : theme.colorScheme.error),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${p.type} · ${p.maskedApiKey.isEmpty ? '未配置 Key' : p.maskedApiKey}'
                          ' · ${p.modelCount} 个模型\n${p.baseUrl}',
                          style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        children: [
                          if (p.modelCount == 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('暂无模型规格（路由候选仍可用 "平台/模型"）',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant)),
                            )
                          else
                            for (final m in _modelListOf(p))
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.view_in_ar_outlined,
                                    size: 16),
                                title: Text(m.modelId,
                                    style: const TextStyle(fontSize: 13)),
                                subtitle: Text(
                                  'ctx=${m.contextWindow > 0 ? m.contextWindow : '-'}'
                                  ' · ${m.capabilities.join(',')}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 15),
                                      onPressed: () =>
                                          _showModelDialog(p.name, existing: m),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline,
                                          size: 15),
                                      onPressed: () => _deleteModel(p.name, m),
                                    ),
                                  ],
                                ),
                              ),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () =>
                                    _showModelDialog(p.name),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('添加模型'),
                              ),
                              TextButton.icon(
                                onPressed: () => _testProvider(p),
                                icon: const Icon(Icons.wifi_tethering,
                                    size: 16),
                                label: const Text('测试连通'),
                              ),
                              const Spacer(),
                              PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') _showProviderDialog(existing: p);
                                  if (v == 'delete') _deleteProvider(p);
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                      value: 'edit', child: Text('编辑平台')),
                                  PopupMenuItem(
                                      value: 'delete', child: Text('删除平台')),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 懒加载平台模型列表：展开时才拉详情（列表接口不含模型明细）。
  final Map<String, List<ModelSpecInfo>> _modelCache = {};

  List<ModelSpecInfo> _modelListOf(ProviderSummary p) {
    final cached = _modelCache[p.name];
    if (cached != null) return cached;
    _modelCache[p.name] = const [];
    ref
        .read(systemRepositoryProvider.future)
        .then((repo) => repo.modelProviderDetail(p.name))
        .then((d) {
          if (mounted) setState(() => _modelCache[p.name] = d.models);
        })
        .catchError((Object _) {});
    return _modelCache[p.name]!;
  }
}

/// 能力中心 Tab：已注册外部项目能力及实例状态。
class _CapabilityTab extends ConsumerStatefulWidget {
  const _CapabilityTab();

  @override
  ConsumerState<_CapabilityTab> createState() => _CapabilityTabState();
}

class _CapabilityTabState extends ConsumerState<_CapabilityTab> {
  Future<List<CapabilitySummary>>? _capabilities;

  @override
  void initState() {
    super.initState();
    _capabilities = ref
        .read(systemRepositoryProvider.future)
        .then((repo) => repo.capabilities())
        .catchError((Object e) => <CapabilitySummary>[]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
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
                    const Text('能力中心',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    FutureBuilder<List<CapabilitySummary>>(
                      future: _capabilities,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        final caps = snap.data ?? const [];
                        if (caps.isEmpty) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              '暂无已注册能力。外部项目可通过 POST '
                              '/api/capabilities/register 注册业务能力，'
                              'Agent 即可在对话中调用',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final c in caps) _capabilityTile(c, theme),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _capabilityTile(CapabilitySummary c, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.name,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          if (c.description.isNotEmpty)
            Text(c.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 3),
          for (final inst in c.instances)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: inst.isUp
                          ? Colors.green.shade400
                          : inst.status == 'SUSPECT'
                              ? Colors.orange
                              : theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${inst.appName} · ${inst.mode.toUpperCase()} · '
                      '${inst.endpointMode} · ${inst.status}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 日志 Tab：读取本地日志文件（客户端日志持久化目录）供排查。
class _LogTab extends ConsumerStatefulWidget {
  const _LogTab();

  @override
  ConsumerState<_LogTab> createState() => _LogTabState();
}

class _LogTabState extends ConsumerState<_LogTab> {
  String _content = '';
  String? _dir;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final dir = CosyLogger.instance.directory;
    if (dir == null) {
      setState(() => _dir = null);
      return;
    }
    final d = Directory(dir);
    if (!await d.exists()) return;
    final files = await d
        .list()
        .where((e) => e is File && e.path.endsWith('.log'))
        .cast<File>()
        .toList()
        .then((list) => list..sort((a, b) => b.path.compareTo(a.path)));
    String content = '';
    if (files.isNotEmpty) {
      // 读最近文件尾部（约 200 行）
      final lines = await files.first.readAsLines();
      final tail = lines.length > 200 ? lines.sublist(lines.length - 200) : lines;
      content = tail.join('\n');
    }
    if (!mounted) return;
    setState(() {
      _dir = dir;
      _content = content;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _dir == null
                          ? '日志目录未初始化（可能尚未写入）'
                          : '目录：$_dir',
                      style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: '刷新',
                    icon: const Icon(Icons.refresh),
                    onPressed: _refresh,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _content.isEmpty
                  ? Center(
                      child: Text('暂无日志内容',
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant)),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: SelectableText(
                        _content,
                        style: const TextStyle(
                            fontSize: 11, fontFamily: 'monospace', height: 1.5),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 结构化路由规则编辑器：候选 = 已注册平台 + 该平台已登记模型的强引用。
///
/// 规则类型 → 有序候选链；候选只能从"平台 × 该平台模型规格"中选择（防拼写错误），
/// 顺序可上移/下移（降级顺序）；规则引用的模型未登记时保存由后端自动补登记并返回提示。
class _RulesEditorPage extends ConsumerStatefulWidget {
  final Map<String, List<String>> initialRules;
  final List<ProviderSummary> providers;
  final Map<String, List<ModelSpecInfo>> modelsByProvider;

  const _RulesEditorPage({
    required this.initialRules,
    required this.providers,
    required this.modelsByProvider,
  });

  @override
  ConsumerState<_RulesEditorPage> createState() => _RulesEditorPageState();
}

class _RulesEditorPageState extends ConsumerState<_RulesEditorPage> {
  late final List<_RuleEntry> _entries;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _entries = widget.initialRules.entries.map((e) {
      final entry = _RuleEntry(e.key);
      for (final c in e.value) {
        final idx = c.indexOf('/');
        if (idx > 0) {
          entry.candidates
              .add(_Candidate(c.substring(0, idx), c.substring(idx + 1)));
        }
      }
      return entry;
    }).toList();
    if (_entries.isEmpty) _entries.add(_RuleEntry('default'));
  }

  List<String> _modelIdsOf(String platform) =>
      widget.modelsByProvider[platform]?.map((m) => m.modelId).toList() ??
      const [];

  Future<void> _save() async {
    if (_saving) return;
    final rules = <String, List<String>>{};
    for (final e in _entries) {
      final type = e.type.text.trim();
      if (type.isEmpty) continue;
      rules[type] = e.candidates.map((c) => '${c.platform}/${c.model}').toList();
    }
    setState(() => _saving = true);
    try {
      final repo = await ref.read(systemRepositoryProvider.future);
      final result = await repo.updateModelRules(rules);
      final registered = result['registeredMissing'] as List? ?? const [];
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(registered.isEmpty
            ? '路由规则已保存'
            : '已保存，并自动登记规则引用的模型：${registered.join('、')}'),
      ));
      Navigator.pop(context, true);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('保存失败：${e is ApiException ? e.message : e}'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('路由规则'),
        actions: [
          TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '候选 = 已注册平台 + 该平台已登记模型；顺序即降级顺序。'
            '规则引用的模型未登记时保存将自动登记。',
            style: TextStyle(
                fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _entries.length; i++) _ruleCard(i, theme),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(
                  () => _entries.add(_RuleEntry('route${_entries.length + 1}'))),
              icon: const Icon(Icons.add),
              label: const Text('添加规则类型'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleCard(int index, ThemeData theme) {
    final entry = _entries[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: entry.type,
                    decoration: const InputDecoration(
                        labelText: '规则类型', isDense: true),
                  ),
                ),
                IconButton(
                  tooltip: '删除该规则',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: _entries.length > 1
                      ? () => setState(() => _entries.removeAt(index))
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (var j = 0; j < entry.candidates.length; j++)
              _candidateRow(entry, j),
            _addCandidateRow(entry),
          ],
        ),
      ),
    );
  }

  Widget _candidateRow(_RuleEntry entry, int j) {
    final c = entry.candidates[j];
    final models = _modelIdsOf(c.platform);
    final modelMissing = models.isNotEmpty && !models.contains(c.model);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: c.platform,
              isDense: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              items: [
                for (final p in widget.providers)
                  DropdownMenuItem(
                      value: p.name,
                      child: Text(p.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() {
                c.platform = v ?? c.platform;
                final ids = _modelIdsOf(c.platform);
                c.model = ids.isEmpty
                    ? ''
                    : (ids.contains(c.model) ? c.model : ids.first);
              }),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: models.contains(c.model) ? c.model : null,
              isDense: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                labelText: modelMissing && c.model.isNotEmpty ? '⚠ 将自动登记' : null,
              ),
              items: [
                for (final m in models)
                  DropdownMenuItem(
                      value: m, child: Text(m, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => c.model = v ?? c.model),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 16),
            onPressed: j == 0
                ? null
                : () => setState(() {
                      final t = entry.candidates[j];
                      entry.candidates[j] = entry.candidates[j - 1];
                      entry.candidates[j - 1] = t;
                    }),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, size: 16),
            onPressed: j == entry.candidates.length - 1
                ? null
                : () => setState(() {
                      final t = entry.candidates[j];
                      entry.candidates[j] = entry.candidates[j + 1];
                      entry.candidates[j + 1] = t;
                    }),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 16),
            onPressed: () => setState(() => entry.candidates.removeAt(j)),
          ),
        ],
      ),
    );
  }

  Widget _addCandidateRow(_RuleEntry entry) {
    String? platform;
    String? model;
    return StatefulBuilder(
      builder: (context, setLocal) {
        final models =
            platform == null ? const <String>[] : _modelIdsOf(platform!);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: null,
                  isDense: true,
                  hint: const Text('平台'),
                  items: [
                    for (final p in widget.providers)
                      DropdownMenuItem(value: p.name, child: Text(p.name)),
                  ],
                  onChanged: (v) => setLocal(() {
                    platform = v;
                    model = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: null,
                  isDense: true,
                  hint: const Text('模型'),
                  items: [
                    for (final m in models)
                      DropdownMenuItem(value: m, child: Text(m)),
                  ],
                  onChanged: (v) => setLocal(() => model = v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                onPressed: platform == null || model == null
                    ? null
                    : () {
                        setState(() =>
                            entry.candidates.add(_Candidate(platform!, model!)));
                        setLocal(() {
                          platform = null;
                          model = null;
                        });
                      },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 编辑器内部：一条规则类型 + 有序候选。
class _RuleEntry {
  final TextEditingController type;
  final List<_Candidate> candidates;

  _RuleEntry(String t)
      : type = TextEditingController(text: t),
        candidates = [];
}

/// 编辑器内部：候选（平台 + 模型，强引用平台模型规格）。
class _Candidate {
  String platform;
  String model;

  _Candidate(this.platform, this.model);
}
