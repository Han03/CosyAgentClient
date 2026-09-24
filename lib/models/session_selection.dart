/// 当前会话选择（桌面单实例对话页驱动用）。
/// sessionId 为 null 表示"新会话"（空会话界面）；title 为会话名（首条消息），
/// 列表点击时随选择一并传入，避免重新进入时再查接口。
class SessionSelection {
  final String? sessionId;
  final String? title;

  const SessionSelection(this.sessionId, this.title);

  @override
  bool operator ==(Object other) =>
      other is SessionSelection &&
      other.sessionId == sessionId &&
      other.title == title;

  @override
  int get hashCode => Object.hash(sessionId, title);
}
