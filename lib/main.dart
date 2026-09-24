import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/logging/cosy_logger.dart';
import 'core/network/api_client.dart';
import 'features/splash/splash_page.dart';
import 'providers/app_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final logger = CosyLogger.instance;
  runZonedGuarded(
    () async {
      await logger.init();
      logger.info(
          'sys',
          '启动: version=1.0.0 builtinBaseUrl=${AppSettings.defaults().baseUrl} '
          'builtinMock=${AppSettings.defaults().mockEnabled} logDir=${logger.directory ?? 'unavailable'}');
      FlutterError.onError = (details) {
        logger.error('app', 'FlutterError: ${details.exception}',
            details.exception, details.stack);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        logger.error('app', 'PlatformDispatcher error: $error', error, stack);
        return true;
      };
      runApp(const ProviderScope(child: CosyAgentApp()));
    },
    (error, stack) {
      logger.error('app', '未捕获异常: $error', error, stack);
    },
  );
}

class CosyAgentApp extends ConsumerWidget {
  const CosyAgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(bootstrapProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'CosyAgent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: router,
      // 启动引导期间覆盖为主界面为加载页（路由/Navigator 保留，就绪后无缝切换）
      builder: (context, child) =>
          bootstrap.isLoading ? const SplashPage() : child!,
    );
  }
}
