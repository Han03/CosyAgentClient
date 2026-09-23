# CosyAgentClient

基于 **Flutter** 的 **CosyAgent** 企业级 ReAct 智能体跨平台客户端（Android / iOS / Windows / macOS / Linux / Web）。

> 服务端：https://github.com/Han03/CosyAgent（Spring AI ReAct Agent）
> 设计方案：[docs/Flutter客户端设计方案.md](docs/Flutter客户端设计方案.md)（工程骨架按方案落地）

## 已落地能力（P0 骨架）

| 模块 | 内容 |
| --- | --- |
| 网络层 | Dio + 拦截器链（Auth 注入 X-API-Key / 统一解包 Result / 错误映射 / 脱敏日志），`core/network/` |
| 数据模型 | 与服务端 DTO 对齐：AgentResult / AgentMessage / AgentTask / TaskDetail / KnowledgeHit / AgentState |
| 仓库层 | ChatRepository（chat/resume）、TaskRepository（详情/列表）、KnowledgeRepository（入库/检索）、SystemRepository（状态/工具/健康） |
| 页面 | 会话列表、对话页（消息流 + 工具轨迹折叠 + 断点恢复）、任务列表、任务详情（轨迹时间线）、知识库（RAG）、设置（服务地址/API Key/连通测试） |
| 配置 | `--dart-define=COSY_BASE_URL` / `COSY_API_KEY` 默认值 + 设置页安全存储覆盖 |

## 快速开始

```bash
# 1. 服务端（Mock 模式无 Key 全链路演示）
cd C:\MyProjects\CosyAgent
$env:COSY_AGENT_MOCK_ENABLED='true'; $env:SERVER_PORT='28080'
java -jar target\cosy-agent-0.1.0-SNAPSHOT.jar

# 2. 客户端（Windows 桌面）
cd C:\MyProjects\CosyAgentClient
flutter pub get
flutter run -d windows --dart-define=COSY_BASE_URL=http://localhost:28080

# 3. 验证
flutter analyze   # No issues found
flutter test      # 4 项模型单测通过
```

## 目录结构

```
lib/
├── main.dart                  # ProviderScope + MaterialApp.router
├── app/                       # go_router 路由表、主题
├── core/
│   ├── network/               # ApiClient（拦截器链）、ApiException
│   └── storage/               # SettingsStore（baseUrl + API Key 安全存储）
├── models/                    # 与服务端 DTO 对齐的模型
├── data/repositories/         # Chat / Task / Knowledge / System
├── providers/                 # Riverpod providers（apiClient 等）
├── features/
│   ├── chat/                  # 会话列表 + 对话页
│   ├── tasks/                 # 任务列表 + 详情（轨迹时间线）
│   ├── knowledge/             # 知识库（RAG）
│   └── settings/              # 设置页
└── widgets/                   # 状态徽章等通用组件
```

## 演进路线

P1：SSE 流式输出（打字机效果）· P2：实时任务进度（WebSocket）/ 语音 · P3：多会话搜索 / 企业 SSO / 富媒体
