class Notification {
  final String id;
  final String content;
  final String status;
  final DateTime timestamp;

  Notification({
    required this.id,
    required this.content,
    required this.status,
    required this.timestamp,
  });

  Notification copyWith({
    String? id,
    String? content,
    String? status,
    DateTime? timestamp,
  }) {
    return Notification(
      id: id ?? this.id,
      content: content ?? this.content,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mensagemId': id,
      'conteudoMensagem': content,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['mensagemId'] ?? json['id'] ?? '',
      content: json['conteudoMensagem'] ?? json['content'] ?? '',
      status: json['status'] ?? 'DESCONHECIDO',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Notification{id: $id, content: $content, status: $status, timestamp: $timestamp}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Notification && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}