import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../models/agent_message.dart';
import '../../models/agent_result.dart';
import '../../providers/app_providers.dart';

/// 对话页：消息流 + 输入框 + 工具调用轨迹（折叠）+ 断点恢复。
class ChatPage extends ConsumerStatefulWidget {
  final String sessionId;

  const ChatPage({super.key, required this.sessionId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final List<AgentMessage> _messages = [];
  final Set<int> _expanded = {};
  bool _sending = false;
  String? _lastTaskId;

  Future<void> _send(String input) async {
    if (input.trim().isEmpty || _sending) return;
    setState(() {
      _messages.add(AgentMessage(role: 'USER', content: input.trim()));
      _sending = true;
    });
    _controller.clear();

    try {
      final repo = await ref.read(chatRepositoryProvider.future);
      final AgentResult result = await repo.chat(widget.sessionId, input.trim());
      if (!mounted) return;
      setState(() {
        _messages.addAll(result.trace
            .where((m) => m.role != 'USER' || m.content != input.trim())
            .toList());
        _messages.add(AgentMessage(role: 'ASSISTANT', content: result.answer));
        _lastTaskId = result.taskId;
        _sending = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(AgentMessage(
            role: 'ASSISTANT',
            content: e is ApiException ? e.message : '请求失败，请检查服务端'));
        _sending = false;
      });
    }
  }

  Future<void> _resume() async {
    final taskId = _lastTaskId;
    if (taskId == null || _sending) return;
    setState(() => _sending = true);
    try {
      final repo = await ref.read(chatRepositoryProvider.future);
      final result = await repo.resume(taskId, '继续');
      if (!mounted) return;
      setState(() {
        _messages.add(AgentMessage(role: 'ASSISTANT', content: result.answer));
        _lastTaskId = result.taskId;
        _sending = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(AgentMessage(
            role: 'ASSISTANT',
            content: e is ApiException ? e.message : '恢复失败'));
        _sending = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('会话 ${widget.sessionId}'),
        actions: [
          if (_lastTaskId != null)
            TextButton(
              onPressed: _sending ? null : _resume,
              child: const Text('继续执行'),
            ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: '任务列表',
            onPressed: () => context.push('/tasks'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) {
                  return const _ThinkingTile();
                }
                return _MessageTile(
                  message: _messages[i],
                  expanded: _expanded.contains(i),
                  onToggle: () => setState(() {
                    if (!_expanded.remove(i)) _expanded.add(i);
                  }),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_sending,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '输入任务描述，如：现在几点？',
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: _sending ? null : () => _send(_controller.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final AgentMessage message;
  final bool expanded;
  final VoidCallback onToggle;

  const _MessageTile({
    required this.message,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'USER';
    final content = message.content ?? '';
    final Widget body = message.isTool
        ? _ToolBubble(message: message, expanded: expanded, onToggle: onToggle)
        : Text(content);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: body,
      ),
    );
  }
}

class _ToolBubble extends StatelessWidget {
  final AgentMessage message;
  final bool expanded;
  final VoidCallback onToggle;

  const _ToolBubble({
    required this.message,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final toolName = message.toolName ?? 'tool';
    return InkWell(
      onTap: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction, size: 14),
              const SizedBox(width: 4),
              Text('调用工具 $toolName', style: const TextStyle(fontSize: 12)),
              Icon(expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16),
            ],
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                message.content ?? '',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThinkingTile extends StatelessWidget {
  const _ThinkingTile();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Agent 执行中…', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
