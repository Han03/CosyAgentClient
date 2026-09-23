import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 会话列表：本地会话分组（本期为演示骨架，后续接 Hive 缓存）。
class ConversationListPage extends StatefulWidget {
  const ConversationListPage({super.key});

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  final List<String> _sessions = ['s1', 's2'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CosyAgent 会话'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: _sessions.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) => ListTile(
          leading: const Icon(Icons.forum_outlined),
          title: Text('会话 ${_sessions[i]}'),
          subtitle: Text(_sessions[i]),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/chat/${_sessions[i]}'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final id = 's${DateTime.now().millisecondsSinceEpoch}';
          setState(() => _sessions.insert(0, id));
          context.push('/chat/$id');
        },
        icon: const Icon(Icons.add),
        label: const Text('新建会话'),
      ),
    );
  }
}
