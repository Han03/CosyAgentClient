import 'package:flutter/material.dart';

import '../app/theme.dart';

/// 会话卡片（会话列表 / 桌面侧栏共用样式）：右侧操作菜单（置顶/重命名/删除）。
class SessionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool pinned;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const SessionCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.selected = false,
    this.pinned = false,
    required this.onTap,
    required this.onPin,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.only(left: 12, top: 10, bottom: 10, right: 2),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.forum_outlined,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (pinned)
                  Icon(Icons.push_pin,
                      size: 15, color: theme.colorScheme.primary),
                PopupMenuButton<String>(
                  tooltip: '会话操作',
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onSelected: (v) => switch (v) {
                    'pin' => onPin(),
                    'rename' => onRename(),
                    'delete' => onDelete(),
                    _ => null,
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'pin',
                        child: Text(pinned ? '取消置顶' : '置顶')),
                    const PopupMenuItem(value: 'rename', child: Text('重命名')),
                    PopupMenuItem(
                        value: 'delete',
                        child: Text('删除',
                            style: TextStyle(color: theme.colorScheme.error))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
