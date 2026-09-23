import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../widgets/session_card.dart';

/// 响应式外壳：宽屏（≥900）桌面三栏式侧栏 + 内容区；窄屏底部导航。
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  static const _destinations = [
    (icon: Icons.forum_outlined, label: '会话'),
    (icon: Icons.receipt_long_outlined, label: '任务'),
    (icon: Icons.book_outlined, label: '知识库'),
    (icon: Icons.settings_outlined, label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      return wide ? _buildWide(context) : _buildNarrow(context);
    });
  }

  // ---- 桌面端：左侧会话栏 + 内容区 ----
  Widget _buildWide(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 300,
            child: _ConversationPane(
              onSelect: (id) => navigationShell.goBranch(0),
              currentIndex: navigationShell.currentIndex,
              onNav: (i) => navigationShell.goBranch(i,
                  initialLocation: i == navigationShell.currentIndex),
            ),
          ),
          VerticalDivider(width: 1, color: theme.dividerColor),
          Expanded(
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerLowest,
              child: navigationShell,
            ),
          ),
        ],
      ),
    );
  }

  // ---- 移动端：内容区 + 底部导航 ----
  Widget _buildNarrow(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(i,
            initialLocation: i == navigationShell.currentIndex),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}

/// 桌面端左侧会话栏（品牌 + 新建 + 会话列表 + 设置入口）。
class _ConversationPane extends StatefulWidget {
  final ValueChanged<String> onSelect;
  final int currentIndex;
  final ValueChanged<int> onNav;

  const _ConversationPane({
    required this.onSelect,
    required this.currentIndex,
    required this.onNav,
  });

  @override
  State<_ConversationPane> createState() => _ConversationPaneState();
}

class _ConversationPaneState extends State<_ConversationPane> {
  final List<String> _sessions = ['s1', 's2'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          // 品牌区
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      size: 17, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'CosyAgent',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          // 新建会话
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final id = 's${DateTime.now().millisecondsSinceEpoch}';
                  setState(() => _sessions.insert(0, id));
                  context.push('/chat/$id');
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新建会话'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(color: theme.colorScheme.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
            ),
          ),
          // 会话列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _sessions.length,
              itemBuilder: (context, i) {
                final id = _sessions[i];
                return SessionCard(
                  title: '会话 $id',
                  subtitle: id,
                  onTap: () {
                    widget.onSelect(id);
                    context.push('/chat/$id');
                  },
                );
              },
            ),
          ),
          // 底部导航（桌面快捷入口）
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final (i, d) in [
                  (0, (icon: Icons.forum_outlined, label: '会话')),
                  (1, (icon: Icons.receipt_long_outlined, label: '任务')),
                  (2, (icon: Icons.book_outlined, label: '知识库')),
                  (3, (icon: Icons.settings_outlined, label: '设置')),
                ])
                  _NavButton(
                    icon: d.icon,
                    label: d.label,
                    selected: widget.currentIndex == i,
                    onTap: () => widget.onNav(i),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// 会话卡片（会话列表 / 桌面侧栏共用样式）。
