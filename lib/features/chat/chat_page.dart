import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/logging/cosy_logger.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/json_format.dart';
import '../../models/agent_message.dart';
import '../../models/session_selection.dart';
import '../../models/session_summary.dart';
import '../../providers/app_providers.dart';

/// 对话页：仿豆包消息流（空状态 / 气泡 / ReAct 步骤卡 / 输入胶囊）。
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
  String? _thinkingText; // 流式思考态文案（thinking 事件更新轮次；reasoning/tool 到达后清除）
  final Map<String, int> _toolIndex = {}; // 工具 callId -> 消息下标（toolResult 回填）
  int? _typingIndex; // 打字机进行中的回答消息下标（点击/完成即清除）
  _TaskSummary? _summary; // done 事件后的任务终态摘要条

  @override
  void initState() {
    super.initState();
    // 恢复会话模型选择（本地持久化），后续由选择条修改
    ref.read(defaultModelProvider.notifier).load();
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
        _toolIndex.clear();
        _thinkingText = null;
        _typingIndex = null;
        _summary = null;
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
        _toolIndex.clear();
        _thinkingText = null;
        _typingIndex = null;
        _summary = null;
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

    final userText = input.trim();
    try {
      final repo = await ref.read(chatRepositoryProvider.future);
      final modelChoice = ref.read(defaultModelProvider);
      // 流式对话：逐事件实时渲染（思考 / 工具步骤 / 回答 / 终态摘要）
      final stream = repo.chatStream(_sessionId, userText, modelChoice: modelChoice);
      await for (final event in stream) {
        if (!mounted) return; // 页面销毁：停止消费流
        switch (event.type) {
          case 'thinking':
            setState(() => _thinkingText = '正在思考…（第 ${event.index ?? 1} 轮）');
            break;
          case 'reasoning':
            setState(() {
              _messages.add(AgentMessage(
                  role: 'REASONING', content: event.content ?? ''));
              _thinkingText = null;
            });
            break;
          case 'tool':
            setState(() {
              _messages.add(AgentMessage(
                  role: 'TOOL',
                  toolCallId: event.callId,
                  toolName: event.toolName,
                  toolArguments: event.arguments,
                  content: null)); // 结果未回：卡头显示"执行中"状态
              if (event.callId != null) {
                _toolIndex[event.callId!] = _messages.length - 1;
              }
              _thinkingText = null;
            });
            break;
          case 'toolResult':
            final idx = event.callId == null ? null : _toolIndex[event.callId];
            if (idx != null) {
              setState(() {
                _messages[idx] = AgentMessage(
                    role: 'TOOL',
                    toolCallId: event.callId,
                    toolName: event.toolName,
                    toolArguments: _messages[idx].toolArguments,
                    content: event.content,
                    durationMs: event.durationMs);
                _toolIndex.remove(event.callId);
              });
            }
            break;
          case 'answer':
            setState(() {
              _messages.add(AgentMessage(role: 'ASSISTANT', content: event.content));
              _typingIndex = _messages.length - 1;
              _thinkingText = null;
            });
            break;
          case 'done':
            setState(() {
              // 首条消息触发会话创建：绑定服务端生成的 sessionId，会话名 = 首条消息
              if (_sessionId == null || _sessionId!.isEmpty) {
                _sessionId = event.sessionId;
                _title = userText;
              }
              _lastTaskId = event.taskId;
              _summary = _TaskSummary(
                state: event.state ?? 'COMPLETED',
                iterations: event.iterations ?? 0,
                costMs: event.costMs ?? 0,
                errorMessage: event.errorMessage,
              );
              _thinkingText = null;
              _typingIndex = null;
              _sending = false;
            });
            break;
          case 'error':
            setState(() {
              _messages.add(AgentMessage(
                  role: 'ERROR',
                  content: event.errorMessage ?? '执行出错'));
              _thinkingText = null;
              _typingIndex = null;
              _sending = false;
            });
            break;
        }
        _scrollToBottom();
      }
      // 流自然结束兜底（服务端异常提前断流时释放输入）
      if (mounted && _sending) {
        setState(() {
          _thinkingText = null;
          _typingIndex = null;
          _sending = false;
        });
      }
      if (mounted && _sessionId != null && _sessionId!.isNotEmpty) {
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
            role: 'ERROR',
            content: e is ApiException ? e.message : '请求失败，请检查服务端'));
        _thinkingText = null;
        _typingIndex = null;
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
      final modelChoice = ref.read(defaultModelProvider);
      final result = await repo.resume(taskId, '继续', modelChoice: modelChoice);
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
            role: 'ERROR',
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
                        itemCount: _messages.length +
                            (_summary != null ? 1 : 0) +
                            (_sending && _thinkingText != null ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _messages.length && _summary != null) {
                            return _TaskSummaryBar(summary: _summary!);
                          }
                          if (i == _messages.length + (_summary != null ? 1 : 0)) {
                            return _ThinkingTile(text: _thinkingText);
                          }
                          return _MessageTile(
                            message: _messages[i],
                            typing: i == _typingIndex,
                            expanded: _expanded.contains(i),
                            onToggle: () => setState(() {
                              if (!_expanded.remove(i)) _expanded.add(i);
                            }),
                            onTypingDone: () {
                              if (_typingIndex == i) _typingIndex = null;
                            },
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _ModelBar(),
                      const SizedBox(height: 6),
                      _InputBar(
                        controller: _controller,
                        enabled: !_sending,
                        onSend: () => _send(_controller.text),
                      ),
                    ],
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

/// done 事件后的任务终态摘要。
class _TaskSummary {
  final String state;
  final int iterations;
  final int costMs;
  final String? errorMessage;

  const _TaskSummary({
    required this.state,
    required this.iterations,
    required this.costMs,
    this.errorMessage,
  });
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

/// 消息气泡与步骤卡分发：用户右（渐变蓝底）/ AI 左（灰底）；
/// TOOL → 工具步骤卡；REASONING → 思考卡；ERROR → 错误卡。
class _MessageTile extends StatelessWidget {
  final AgentMessage message;
  final bool typing;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onTypingDone;

  const _MessageTile({
    required this.message,
    required this.typing,
    required this.expanded,
    required this.onToggle,
    required this.onTypingDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (message.isTool) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _ToolStepCard(
            message: message, expanded: expanded, onToggle: onToggle),
      );
    }
    if (message.role == 'REASONING') {
      return Align(
        alignment: Alignment.centerLeft,
        child: _ReasoningCard(
            content: message.content ?? '', expanded: expanded, onToggle: onToggle),
      );
    }
    if (message.role == 'ERROR') {
      return Align(
        alignment: Alignment.centerLeft,
        child: _ErrorBubble(content: message.content ?? ''),
      );
    }
    final isUser = message.role == 'USER';
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
        child: typing
            ? _TypewriterText(
                text: message.content ?? '',
                onDone: onTypingDone,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isUser
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
              )
            : Text(
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

/// 打字机回答：answer 全文到达后逐字渐进显示，点击立即全显。
class _TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final VoidCallback onDone;

  const _TypewriterText({
    required this.text,
    required this.style,
    required this.onDone,
  });

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  static const _stepChars = 3; // 每帧 reveal 字符数
  int _revealed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer = Timer.periodic(const Duration(milliseconds: 20), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _revealed += _stepChars;
        if (_revealed >= widget.text.length) {
          _revealed = widget.text.length;
          t.cancel();
          widget.onDone();
        }
      });
    });
  }

  void _revealAll() {
    _timer?.cancel();
    setState(() => _revealed = widget.text.length);
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _revealAll,
      child: Text(widget.text.substring(0, _revealed), style: widget.style),
    );
  }
}

/// 思考卡：模型在工具调用前的推理文本（只渲染不落库）。
class _ReasoningCard extends StatelessWidget {
  final String content;
  final bool expanded;
  final VoidCallback onToggle;

  const _ReasoningCard({
    required this.content,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.psychology_outlined,
                        size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    const Text(
                      '思考过程',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
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
                const SizedBox(height: 4),
                Text(
                  expanded ? content : truncateText(content, 120),
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 工具步骤卡：工具名 + 状态徽标（执行中/完成/失败）+ 参数/结果双折叠。
class _ToolStepCard extends StatelessWidget {
  final AgentMessage message;
  final bool expanded;
  final VoidCallback onToggle;

  const _ToolStepCard({
    required this.message,
    required this.expanded,
    required this.onToggle,
  });

  IconData _toolIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('time')) return Icons.schedule;
    if (n.contains('calc') || n.contains('calculat')) return Icons.calculate;
    if (n.contains('know') || n.contains('search')) return Icons.book_outlined;
    if (n.contains('weather')) return Icons.cloud_outlined;
    return Icons.construction;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolName = message.toolName ?? 'tool';
    final running = message.content == null; // 结果未回 → 执行中
    final failed = !running && isErrorResult(message.content!);
    final durationMs = message.durationMs;
    final iconColor = failed
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_toolIcon(toolName), size: 14, color: iconColor),
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
                    if (running)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else ...[
                      Icon(
                        failed
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        size: 14,
                        color: failed
                            ? theme.colorScheme.error
                            : Colors.green,
                      ),
                      if (durationMs != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          durationMs >= 1000
                              ? '${(durationMs / 1000).toStringAsFixed(1)}s'
                              : '${durationMs}ms',
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                    const SizedBox(width: 2),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (expanded) ...[
                  if (running)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('执行中…',
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant)),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.toolArguments != null &&
                              message.toolArguments!.isNotEmpty) ...[
                            _JsonBlock(
                              label: '参数',
                              content: message.toolArguments!,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 6),
                          ],
                          _JsonBlock(
                            label: '结果',
                            content: message.content ?? '',
                            color: failed
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 折叠 JSON 展示块（美化 + 超长截断）。
class _JsonBlock extends StatelessWidget {
  final String label;
  final String content;
  final Color color;

  const _JsonBlock({
    required this.label,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pretty = prettyJson(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color)),
        const SizedBox(height: 3),
        Text(
          truncateText(pretty, 500),
          style: TextStyle(
              fontSize: 12,
              height: 1.5,
              fontFamily: 'monospace',
              color: color),
        ),
      ],
    );
  }
}

/// 任务终态摘要条：状态徽标 + 轮次 + 耗时。
class _TaskSummaryBar extends StatelessWidget {
  final _TaskSummary summary;

  const _TaskSummaryBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, label) = switch (summary.state) {
      'COMPLETED' => (Icons.check_circle_outline, Colors.green, 'COMPLETED'),
      'TIMEOUT' => (Icons.timer_outlined, Colors.orange, 'TIMEOUT'),
      _ => (Icons.error_outline, theme.colorScheme.error, 'FAILED'),
    };
    final costText = summary.costMs >= 1000
        ? '${(summary.costMs / 1000).toStringAsFixed(1)}s'
        : '${summary.costMs}ms';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
            const SizedBox(width: 10),
            Text('${summary.iterations} 轮 · $costText',
                style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// 错误卡：执行异常（红色，区别于普通气泡）。
class _ErrorBubble extends StatelessWidget {
  final String content;

  const _ErrorBubble({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
              color: theme.colorScheme.error.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline,
                size: 16, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                content,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: theme.colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Agent 执行中指示（thinking 事件实时更新轮次文案）。
class _ThinkingTile extends StatelessWidget {
  final String? text;

  const _ThinkingTile({this.text});

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
            Text(text ?? 'Agent 执行中…',
                style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// 会话模型选择条（Auto 自动选择 / 指定模型；目录来自后端权威配置，选择本地持久化）。
class _ModelBar extends ConsumerWidget {
  const _ModelBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(defaultModelProvider);
    final catalog = ref.watch(modelCatalogProvider);
    final models = catalog.maybeWhen(
      data: (c) => c.models,
      orElse: () => const <String>[],
    );
    final label = current == 'auto' ? 'Auto' : current;
    return PopupMenuButton<String>(
      tooltip: '选择模型',
      initialValue: current,
      onSelected: (v) => ref.read(defaultModelProvider.notifier).select(v),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'auto', child: Text('Auto 自动选择')),
        ...models.map((m) => PopupMenuItem(value: m, child: Text(m))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined,
                size: 13, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.onSurface)),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down,
                size: 15, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
