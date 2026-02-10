enum UiMessageType {
  info,
  success,
  error,
}

class UiMessage {
  const UiMessage({
    required this.type,
    required this.text,
    this.actionLabel,
    this.actionCallbackId,
  });

  final UiMessageType type;
  final String text;
  final String? actionLabel;
  final String? actionCallbackId;
}
