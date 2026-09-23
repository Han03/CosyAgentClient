import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../models/knowledge_hit.dart';
import '../../providers/app_providers.dart';
import '../../widgets/gradient_button.dart';

/// 知识库（RAG）：入库 / 检索，卡片式功能区。
class KnowledgePage extends ConsumerStatefulWidget {
  const KnowledgePage({super.key});

  @override
  ConsumerState<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends ConsumerState<KnowledgePage> {
  final _namespace = TextEditingController();
  final _docId = TextEditingController();
  final _content = TextEditingController();
  final _query = TextEditingController();
  final _topK = TextEditingController(text: '3');

  List<KnowledgeHit> _hits = [];
  bool _busy = false;
  String? _message;

  Future<void> _upsert() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final repo = await ref.read(knowledgeRepositoryProvider.future);
      final r = await repo.upsert(
        namespace: _namespace.text.isEmpty ? null : _namespace.text,
        docId: _docId.text.isEmpty ? null : _docId.text,
        content: _content.text,
      );
      if (!mounted) return;
      setState(() {
        _message = '入库成功：namespace=${r.namespace} docId=${r.docId} chunks=${r.chunks}';
        _busy = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _message = '入库失败：${e is ApiException ? e.message : e}';
        _busy = false;
      });
    }
  }

  Future<void> _search() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final repo = await ref.read(knowledgeRepositoryProvider.future);
      final hits = await repo.search(
        namespace: _namespace.text.isEmpty ? null : _namespace.text,
        query: _query.text,
        topK: int.tryParse(_topK.text),
      );
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _busy = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _message = '检索失败：${e is ApiException ? e.message : e}';
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    _namespace.dispose();
    _docId.dispose();
    _content.dispose();
    _query.dispose();
    _topK.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('知识库')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                icon: Icons.upload_outlined,
                title: '知识入库',
                subtitle: '将文档写入向量库，供 Agent 检索',
                child: Column(
                  children: [
                    TextField(
                      controller: _namespace,
                      decoration:
                          const InputDecoration(labelText: 'namespace（可选）'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _docId,
                      decoration:
                          const InputDecoration(labelText: 'docId（可选，自动生成）'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _content,
                      minLines: 3,
                      maxLines: 6,
                      decoration:
                          const InputDecoration(labelText: 'content（必填）'),
                    ),
                    const SizedBox(height: 12),
                    GradientButton(
                      label: '入库',
                      icon: Icons.file_upload_outlined,
                      loading: _busy,
                      onPressed: _upsert,
                      expanded: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                icon: Icons.search,
                title: '向量检索',
                subtitle: '语义检索命中文档（RAG 召回）',
                child: Column(
                  children: [
                    TextField(
                      controller: _query,
                      decoration:
                          const InputDecoration(labelText: 'query（必填）'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _topK,
                      decoration:
                          const InputDecoration(labelText: 'topK（默认 3）'),
                    ),
                    const SizedBox(height: 12),
                    GradientButton(
                      label: '检索',
                      icon: Icons.search_rounded,
                      loading: _busy,
                      onPressed: _search,
                      expanded: true,
                    ),
                  ],
                ),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_message!,
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
              const SizedBox(height: 12),
              ..._hits.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(h.docId,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ),
                                Text(
                                  'score ${h.score.toStringAsFixed(3)}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(h.content,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

/// 功能区卡片：图标 + 标题 + 说明 + 内容。
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 18, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
