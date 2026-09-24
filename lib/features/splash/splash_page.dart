import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 启动加载页：应用启动时展示品牌画面，同时后台并行准备启动所需数据
/// （本地配置、会话列表预取、模型目录、默认模型恢复，见 bootstrapProvider）。
/// 数据就绪后由 CosyAgentApp 自动切换到主界面。
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 品牌 Logo 卡片（渐变 + 光晕）
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brand.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.auto_awesome, size: 36, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'CosyAgent',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '正在准备…',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
