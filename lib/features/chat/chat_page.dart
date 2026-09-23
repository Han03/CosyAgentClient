import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/network/api_exception.dart';
import '../../models/agent_message.dart';
import '../../models/agent_result.dart';
import '../../providers/app_providers.dart';

/// 对话页：仿豆包消息流（空状态 / 气泡 / 工具轨迹 / 输入胶囊）。
class ChatPage extends ConsumerStatefulWidget {
  final String sessionId;

  const ChatPage({super.key, required this.sessionId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
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
    _scrollToBottom();

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
      _scrollToBottom();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(AgentMessage(
            role: 'ASSISTANT',
            content: e is ApiException ? e.message : '请求失败，请检查服务端'));
        _sending = false;
      });
      _scrollToBottom();
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
      _scrollToBottom();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(AgentMessage(
            role: 'ASSISTANT',
            content: e is ApiException ? e.message : '恢复失败'));
        _sending = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
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
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _messages.isEmpty && !_sending
                    ? const _EmptyState()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                        itemCount:
                            _messages.length + (_sending ? 1 : 0),
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
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                  child: _InputBar(
                    controller: _controller,
                    enabled: !_sending,
                    onSend: () => _send(_controller.text),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 空状态：品牌图标 + 开场白。
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brand.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome,
                size: 34, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text('有什么可以帮你？',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('输入任务描述，Agent 将自主规划并调用工具完成',
              style: TextStyle(
                  fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// 输入栏：胶囊填充 + 渐变发送按钮。
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: '输入任务描述，如：现在几点？',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 40,
            height: 40,
            child: Material(
              color: enabled ? null : theme.colorScheme.surfaceContainer,
              shape: const CircleBorder(),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: enabled ? AppTheme.brandGradient : null,
                  shape: BoxShape.circle,
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: enabled ? onSend : null,
                  child: const Icon(Icons.arrow_upward_rounded,
                      size: 20, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 消息气泡：用户右（渐变蓝底）/ AI 左（灰底）；工具轨迹窄卡。
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
    final theme = Theme.of(context);
    final isUser = message.role == 'USER';
    if (message.isTool) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _ToolBubble(
            message: message, expanded: expanded, onToggle: onToggle),
      );
    }
    final bubbleColor = isUser
        ? AppTheme.brandGradient
        : LinearGradient(
            colors: [
              theme.colorScheme.surfaceContainerHigh,
              theme.colorScheme.surfaceContainerHigh,
            ],
          );
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          gradient: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppTheme.radiusMd),
            topRight: const Radius.circular(AppTheme.radiusMd),
            bottomLeft: Radius.circular(isUser ? AppTheme.radiusMd : 4),
            bottomRight: Radius.circular(isUser ? 4 : AppTheme.radiusMd),
          ),
        ),
        child: Text(
          message.content ?? '',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isUser
                ? Colors.white
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// 工具调用轨迹卡（可展开）。
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
    final theme = Theme.of(context);
    final toolName = message.toolName ?? 'tool';
    final color = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Container(
            width: 300,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.construction, size: 14, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '调用工具 · $toolName',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (expanded)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      message.content ?? '',
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Agent 执行中指示。
class _ThinkingTile extends StatelessWidget {
  const _ThinkingTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text('Agent 执行中…',
                style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
