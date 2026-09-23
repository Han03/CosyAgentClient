/// 客户端统一错误模型：映射服务端错误码与网络/解析异常。
class ApiException implements Exception {
  /// 服务端业务错误码（0 为成功，此处仅承载非 0 值）。
  final int code;

  /// 人类可读信息。
  final String message;

  /// 是否网络层错误（连接失败/超时等）。
  final bool isNetwork;

  const ApiException(this.code, this.message, {this.isNetwork = false});

  @override
  String toString() => 'ApiException($code, $message, network=$isNetwork)';
}

/// 服务端鉴权失败（401 / 无效 X-API-Key）。
class UnauthorizedException extends ApiException {
  const UnauthorizedException(String message) : super(401, message);
}
