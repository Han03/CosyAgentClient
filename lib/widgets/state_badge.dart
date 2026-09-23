import 'package:flutter/material.dart';

import '../models/agent_state.dart';

/// 任务状态徽章：颜色 + 文案映射。
class StateBadge extends StatelessWidget {
  final AgentState state;

  const StateBadge({super.key, required this.state});

  (Color, String) _style() => switch (state) {
        AgentState.completed => (Colors.green.shade600, '已完成'),
        AgentState.failed => (Colors.red.shade600, '失败'),
        AgentState.timeout => (Colors.orange.shade700, '超时'),
        AgentState.cancelled => (Colors.blueGrey, '已取消'),
        AgentState.init => (Colors.blueGrey, '初始化'),
        _ => (Colors.amber.shade600, '执行中'),
      };

  @override
  Widget build(BuildContext context) {
    final (color, label) = _style();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
