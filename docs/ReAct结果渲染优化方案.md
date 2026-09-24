# 客户端 ReAct 结果渲染优化方案

> 目标：让客户端的 Agent 执行过程呈现与主流 Agent 工具（豆包等）一致——**思考过程、工具调用（参数/状态/结果/耗时）、最终回答（打字机）、任务终态摘要**完整可见。
> 范围：前端为主（`CosyAgentClient`），后端仅做两处最小协议增量（`reasoning` 事件、`toolResult.durationMs`），向后兼容。

---

## 1. 现状与缺口

### 1.1 已实现（`chat_page.dart` 流式消费）

| 事件 | 当前渲染 |
| --- | --- |
| `thinking` | `_ThinkingTile`："正在思考…（第 N 轮）" 转圈 |
| `tool` | `_ToolBubble`：工具名 + 可展开查看**结果** |
| `toolResult` | 回填 content 到对应工具卡 |
| `answer` | 普通 AI 气泡（一次性上屏） |
| `done` | 仅内部绑定 sessionId / 记录 lastTaskId |
| `error` | 混入普通 AI 气泡 |

### 1.2 缺口清单（对照豆包等 Agent 工具）

| # | 缺口 | 现状 | 目标 |
| --- | --- | --- | --- |
| 1 | 思考内容不可见 | thinking 只有"第 N 轮"轮次，模型推理文本（Thought）未透出 | 展示该轮思考文本（`reasoning` 卡片） |
| 2 | 工具参数不可见 | `arguments` 字段已随事件到达但**从未渲染** | 参数 JSON 可折叠查看 |
| 3 | 工具状态无区分 | 执行中/完成/失败同一样式 | 状态徽标：执行中（转圈）/ 完成（✓）/ 失败（✗ 红） |
| 4 | 工具耗时不可见 | `toolResult` 无耗时字段 | 显示单次工具执行耗时 |
| 5 | 终态摘要缺失 | `done` 的 state/iterations/costMs 只内部用 | 任务摘要条：状态徽标 + N 轮 + 耗时 |
| 6 | 回答无"流式感" | answer 一次性全量上屏 | 打字机渐进显示（点击立即全显） |
| 7 | 错误样式不友好 | error 混入普通气泡 | 独立错误卡（红色） |
| 8 | 工具图标单一 | 全部 `construction` | 按工具名映射语义图标（时间/计算/知识/默认） |

---

## 2. 目标形态（渲染模型）

消息流从"扁平气泡流"升级为 **"步骤卡 + 气泡"混合流**：

```
[USER 气泡]
[thinking 转圈]      ← 该轮模型推理开始
[reasoning 思考卡]   ← 该轮模型思考文本（Thought，可折叠）
[tool 步骤卡] ×N     ← 工具名 + 参数(折叠) + 状态徽标 + 耗时 + 结果(折叠)
[answer 打字机气泡]  ← 最终回答逐字呈现
[done 摘要条]        ← COMPLETED ✓ · 3 轮 · 4.2s
```

**关键设计**：渲染层新增**步骤状态**（`_toolStatus`），但**不改 `AgentMessage` 历史模型**——消息是落库快照，工具执行中的瞬时状态（running/耗时）只存在于流式会话期间，历史重载时默认渲染为"完成态"。

---

## 3. 协议变更（后端最小增量，向后兼容）

### 3.1 新增 `reasoning` 事件（该轮思考文本）

**现状**：`thinking` 在模型调用**前** emit（`DefaultReActAgent` L143），只带 `index`，无法携带思考内容。

**改法**：

```
位置：DefaultReActAgent 每轮模型返回后（assistant 已获取，L164）、判断 toolCalls 之前
条件：assistant.getText() 非空才 emit（模型直接发工具调用、无思考文本时跳过）
载荷：{ "type": "reasoning", "index": N, "content": "思考文本" }
```

- `AgentStreamEvent` 新增静态工厂 `reasoning(int index, String content)`，复用现有 `content` 槽位，**record 字段不变**；
- 客户端 `AgentStreamEvent` 无需新增字段（content 已有），仅新增 type 分支。

### 3.2 `toolResult` 增加 `durationMs`（工具耗时）

**现状**：`toolResult` 载荷为 `{callId, toolName, content}`，无耗时。

**改法**：

```
位置：DefaultReActAgent 工具执行循环（L178-196）
做法：执行前 System.nanoTime() 起表，emit 前结算毫秒
载荷：{ "type": "toolResult", "callId", "toolName", "content", "durationMs": 1234 }
```

- `AgentStreamEvent` record 增加第 13 字段 `Long durationMs`（**所有 6 个静态工厂构造点同步补参**）；
- 客户端 `AgentStreamEvent` 增加 `durationMs` 字段（`json['durationMs']`），缺省 null。

### 3.3 不变项

- `thinking`：保持"轮次开始"语义（转圈）；
- `answer` / `done` / `error`：载荷不变；
- **Mock 引擎零成本覆盖**：Mock 走同一 `DefaultReActAgent` 循环，`reasoning` / `durationMs` 自动生效，无需改剧本。

### 3.4 兼容性

| 组合 | 表现 |
| --- | --- |
| 新客户端 + 新后端 | 完整渲染（思考卡/耗时/摘要条） |
| 新客户端 + 旧后端 | 无 `reasoning`（仅转圈）、无 `durationMs`（不显耗时）——全部可选字段兜底 |
| 旧客户端 + 新后端 | 忽略新字段/新事件类型，行为不变 |

---

## 4. 客户端模型变更

### 4.1 `AgentStreamEvent`（`lib/models/agent_stream_event.dart`）

```dart
final int? durationMs;               // toolResult：工具执行耗时(ms)
// fromJson: durationMs: json['durationMs'] as int?
```

### 4.2 `AgentMessage`（不变）

历史消息已含 `toolArguments` 字段（此前未渲染），重载历史时工具卡可直接展示参数——**无模型迁移**。

### 4.3 渲染状态（不进消息模型，仅流式会话内存态）

```dart
// 工具执行状态：callId -> 状态
final Map<String, _ToolRuntime> _toolRuntime = {};
// _ToolRuntime { status: running|done|error, durationMs }
// 由 tool(置 running) / toolResult(置 done；content 含 error 则 error) 事件维护；
// toolResult 到达后从 _toolRuntime 移除，仅保留 _messages（历史快照）
```

---

## 5. 组件设计（`chat_page.dart` 内部重构）

### 5.1 `_ThinkingTile`（保留）

轮次转圈文案，`thinking` 事件更新 index。

### 5.2 `_ReasoningCard`（新增）

```
[psychology 图标] 思考 · 第 N 轮          [展开/折叠]
  内容：模型思考文本（默认折叠成 2 行省略，点击展开全文）
```

- `reasoning` 事件 → 插入消息流（`AgentMessage(role: 'SYSTEM', content: ...)`？**否**——历史不可混淆，用渲染层专用条目）。

> **细节决策**：`reasoning` 卡**只渲染不落库**——它是流式过程的"过程态"，最终 answer + 工具轨迹已足够重建任务；避免 `AgentMessage` 加新 role 影响服务端 trace 语义。

### 5.3 `_ToolStepCard`（升级 `_ToolBubble`）

```
[icon] 调用工具 · get_server_time    [状态徽标]    [折叠箭头]
  │  running: 16px 转圈 + "执行中"
  │  done:    ✓ + "· 1.2s"
  │  error:   ✗ 红色
[展开后]
  ┌ 参数 ──────────────────┐
  │ {"format":"yyyy-MM-dd"}│    ← toolArguments pretty JSON
  └────────────────────────┘
  ┌ 结果 ──────────────────┐
  │ {"time":"2026-09-24…"} │    ← content pretty JSON（error 结果红色）
  └────────────────────────┘
```

- **图标映射**（按工具名关键字，未命中回退 `construction`）：

| 工具名含 | 图标 |
| --- | --- |
| time / 时间 | `Icons.schedule` |
| calc / calculat | `Icons.calculate` |
| know / search / 知识 | `Icons.book_outlined` |
| weather | `Icons.cloud_outlined` |
| 其他 | `Icons.construction` |

- **默认折叠**：仅头部一行（工具名 + 状态），避免刷屏；
- **参数/结果双折叠**：展开卡后并列展示，pretty JSON + 超长（>300 字符）截断省略。

### 5.4 `_AnswerBubble`（升级：打字机）

- answer 全文一次性到达（后端非逐 token，**不改后端流式协议**——成本收益不划算）；
- 客户端模拟打字机：`_TypewriterText`（StatefulWidget）按 2~3 字/帧 reveal，**点击文本立即全显**，`done`/新消息到达自动加速完成；
- 历史重载的 ASSISTANT 消息**不走打字机**（直接全显）。

### 5.5 `_TaskSummaryBar`（新增，done 后插入）

```
[✓ COMPLETED / ✗ FAILED / ⏱ TIMEOUT]  3 轮迭代 · 4.2s
FAILED 时追加：错误原因（errorMessage）
```

- `done` 事件携带 `state / iterations / costMs / errorMessage`，全字段已有；
- 样式：COMPLETED 绿、FAILED 红、TIMEOUT 橙；小字 onSurfaceVariant。

### 5.6 `_ErrorBubble`（新增，error 事件）

- 红色描边/浅红底错误卡（区别于普通 AI 气泡），保留"重试引导"文案（"请检查服务端或稍后重试"）。

### 5.7 JSON 格式化工具（`lib/core/utils/json_format.dart` 新增）

```dart
String prettyJson(String raw) {
  // jsonDecode → JsonEncoder.withIndent('  ').convert
  // 失败（非 JSON，如纯文本观察）→ 原样返回
}
String truncate(String s, int max) { ... }   // 超长折叠
```

---

## 6. 历史消息渲染（`_loadHistory` 兼容）

| 消息 | 渲染 |
| --- | --- |
| `USER` | 用户气泡（现状） |
| `ASSISTANT` | 普通气泡（现状；**不做** "Thought/Action" 文本启发式样式，避免误判） |
| `TOOL` | `_ToolStepCard` **完成态**（含 `toolArguments` 参数折叠 + `content` 结果折叠；无 durationMs → 不显耗时） |

> 历史会话不展示 reasoning 卡与摘要条（trace 中无对应事件、后端任务列表已有独立任务页可查终态），保持历史视图简洁。

---

## 7. 实施步骤

| Phase | 内容 | 验证 |
| --- | --- | --- |
| **P1 后端协议** | `AgentStreamEvent` + `reasoning` 工厂 / + `durationMs` 字段（6 工厂同步）；`DefaultReActAgent` 两处 emit 改造；测试补 `reasoning`/`durationMs` 断言 | `mvn test` 全绿；SSE curl 实测事件序列含新字段 |
| **P2 客户端渲染** | `AgentStreamEvent.durationMs`；`chat_page.dart` 组件重构（`_ReasoningCard`/`_ToolStepCard`/`_TaskSummaryBar`/`_ErrorBubble`/打字机）；`json_format.dart` | `flutter analyze` 0 issue；Mock 模式提问观察完整事件渲染 |
| **P3 历史打磨** | `_loadHistory` TOOL 卡参数展示；折叠默认态；超长截断 | 历史会话重载验证 |
| **P4 收尾** | 双端提交推送；**按工作约定启动最新后端 + 客户端** | 冒烟观察 |

---

## 8. 验收标准

1. **后端**：`mvn test` 全绿（86+ 项）；SSE 事件序列实测：`thinking → reasoning → tool → toolResult(durationMs) → … → answer → done`。
2. **客户端**：`flutter analyze` 0 issue；启动不报错。
3. **体验**（Mock 模式，提问"现在几点？"）：观察到
   - 思考卡（该轮思考文本）→ 工具卡（名称/参数/状态/耗时/结果）→ 打字机回答 → 摘要条（✓ COMPLETED · N 轮 · X 秒）；
   - 注入故障剧本（unknown-tool）→ 工具卡红色 ✗ 状态 + 自愈后继续。
4. **双端运行**：任务完成后后端（8080）+ 客户端保持运行。

---

## 9. 不做的事（范围边界）

- ❌ 后端 answer **逐 token 流式**改造（当前 SSE 一次性全文是已确认形态；打字机客户端模拟已满足体验，改协议收益/成本不划算）
- ❌ reasoning 卡**落库**（保持 trace 语义纯净，避免历史消息模型膨胀）
- ❌ 历史消息的思考文本**启发式样式**（易误判，风险大于收益）
- ❌ 工具卡动画/粒子等装饰（静态信息优先，避免干扰阅读）
