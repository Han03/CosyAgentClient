import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/network/api_exception.dart';
import '../../models/agent_message.dart';
import '../../models/session_summary.dart';
import '../../core/logging/cosy_logger.dart';
import '../../models/session_selection.dart';
import '../../models/agent_result.dart';
import '../../providers/app_providers.dart';

/// 对话页：仿豆包消息流（空状态 / 气泡 / 工具轨迹 / 输入胶囊）。
///
/// [sessionId] 为空表示"新会话"：发送首条消息时才创建会话，
/// 会话名称 = 首条消息（由服务端生成 sessionId 并返回）。
class ChatPage extends ConsumerStatefulWidget {
  final String? sessionId;
  final String? title; // 会话标题（列表点击传入，避免重新进入时再查接口）
  final bool standalone; // true=栈式页面(移动端 push，构造参数驱动)；false=桌面单实例(provider 驱动)

  const ChatPage({super.key, this.sessionId, this.title, this.standalone = false});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<AgentMessage> _messages = [];
  final Set<int> _expanded = {};
  bool _sending = false;
  bool _loadingHistory = false;
  String? _lastTaskId;
  String? _sessionId; // 会话 ID：null = 尚未创建（首条消息发送后由服务端返回）
  String? _title; // 会话名称 = 首条消息

  @override
  void initState() {
    super.initState();
    if (widget.standalone) {
      // 移动端栈式页面：构造参数驱动
      _sessionId = widget.sessionId;
      _title = widget.title;
      if (_sessionId != null && _sessionId!.isNotEmpty) {
        _loadHistory();
      }
    } else {
      // 桌面单实例对话页：初始应用当前选择（listen 在 build 中注册）
      _applySelection(ref.read(currentSessionProvider));
    }
  }

  /// 应用会话选择（桌面单实例）：null/空=空会话；同会话忽略(不重载)；否则加载历史。
  void _applySelection(SessionSelection? sel) {
    CosyLogger.instance
        .info('ui', 'apply selection: ${sel?.sessionId} current=$_sessionId');
    final newId = sel?.sessionId;
    if (newId == null || newId.isEmpty) {
      if (_sessionId == null || _sessionId!.isEmpty) return; // 已在空会话
      setState(() {
        _messages.clear();
        _expanded.clear();
        _sessionId = null;
        _title = null;
        _lastTaskId = null;
        _loadingHistory = false;
      });
      _controller.clear();
    } else {
      if (_sessionId == newId) return; // 同会话：不重新加载
      setState(() {
        _sessionId = newId;
        _title = sel!.title;
        _messages.clear();
        _expanded.clear();
        _lastTaskId = null;
        _loadingHistory = true;
      });
      _loadHistory();
    }
  }

  /// 进入已有会话：加载全部历史消息 + 最新任务（供"继续执行"恢复）。
  Future<void> _loadHistory() async {
    final sid = _sessionId!;
    setState(() => _loadingHistory = true);
    try {
      final chatRepo = await ref.read(chatRepositoryProvider.future);
      final taskRepo = await ref.read(taskRepositoryProvider.future);
      final messages = await chatRepo.sessionMessages(sid);
      final tasks = await taskRepo.listTasks(sessionId: sid, limit: 1);
      SessionSummary? summary;
      try {
        summary = await taskRepo.fetchSession(sid);
      } on Exception {
        summary = null; // 标题获取失败时回退显示会话 id
      }
      if (!mounted) return;
      setState(() {
        _messages.addAll(messages);
        _title = _title ?? summary?.title;
        if (tasks.isNotEmpty) _lastTaskId = tasks.first.taskId;
        _loadingHistory = false;
      });
      _scrollToBottom();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(AgentMessage(
            role: 'ASSISTANT', content: '历史消息加载失败：$e'));
        _loadingHistory = false;
      });
    }
  }

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
      final AgentResult result = await repo.chat(_sessionId, input.trim());
      if (!mounted) return;
      setState(() {
        // 首条消息触发会话创建：记录服务端生成的 sessionId 与会话名（首条消息）
        if (_sessionId == null || _sessionId!.isEmpty) {
          _sessionId = result.sessionId;
          _title = input.trim();
        }
        _messages.addAll(result.trace
            .where((m) => m.role != 'USER' || m.content != input.trim())
            .toList());
        _messages.add(AgentMessage(role: 'ASSISTANT', content: result.answer));
        _lastTaskId = result.taskId;
        _sending = false;
      });
      _scrollToBottom();
      if (_sessionId != null && _sessionId!.isNotEmpty) {
        ref.invalidate(sessionListProvider);
        if (widget.standalone) {
          // 移动端：新会话创建后把 URL 绑定到该会话，点列表同会话不再重建重载
          context.go('/chat/$_sessionId');
        } else {
          // 桌面单实例：更新全局会话选择（同值短路，页面不重载）
          ref.read(currentSessionProvider.notifier).state =
              SessionSelection(_sessionId, _title);
        }
      }
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
    if (!widget.standalone) {
      // 桌面单实例：每次 build 注册监听（Riverpod 自动去重），
      // 点击列表/新建时切换会话内容，不重建页面
      ref.listen<SessionSelection?>(currentSessionProvider, (prev, next) {
        CosyLogger.instance
            .info('ui', 'listen: ${prev?.sessionId} -> ${next?.sessionId}');
        _applySelection(next);
      });
    }
    final hasSession = _sessionId != null && _sessionId!.isNotEmpty;
    final title = _title ?? (hasSession ? '会话 $_sessionId' : '新会话');
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          // 手机模式（standalone 栈式页）不展示操作菜单；桌面单实例页保留
          if (!widget.standalone) ...[
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
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _messages.isEmpty && _loadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty && !_sending
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
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
