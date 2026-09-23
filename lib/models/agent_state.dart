/// Agent 生命周期状态（与服务端 AgentState 枚举对齐）。
enum AgentState {
  init('INIT'),
  planning('PLANNING'),
  running('RUNNING'),
  toolCalling('TOOL_CALLING'),
  completed('COMPLETED'),
  failed('FAILED'),
  timeout('TIMEOUT'),
  cancelled('CANCELLED');

  const AgentState(this.wire);

  /// 服务端 JSON 字面量。
  final String wire;

  static AgentState fromWire(String? value) {
    for (final s in values) {
      if (s.wire == value) return s;
    }
    return AgentState.init;
  }

  bool get isTerminal =>
      this == AgentState.completed ||
      this == AgentState.failed ||
      this == AgentState.timeout ||
      this == AgentState.cancelled;

  bool get isRunning =>
      this == AgentState.running ||
      this == AgentState.planning ||
      this == AgentState.toolCalling;
}
