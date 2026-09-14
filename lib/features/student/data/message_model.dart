/// Immutable data model for a single chat message between a student and
/// a doctor. Mirrors the `public.messages` table - see
/// `create_messages.sql` for the schema.
enum MessageType { text, image, voice }

MessageType messageTypeFromString(String? raw) => switch (raw) {
  'image' => MessageType.image,
  'voice' => MessageType.voice,
  _ => MessageType.text,
};

String messageTypeToString(MessageType type) => switch (type) {
  MessageType.image => 'image',
  MessageType.voice => 'voice',
  MessageType.text => 'text',
};

class ChatMessageModel {
  final String id;
  final String studentId;
  final String doctorId;
  final String senderId;
  final String? appointmentId;
  final MessageType type;
  final String? body;
  final String? attachmentUrl;
  final int? voiceDurationSeconds;
  final DateTime? readAt;
  final DateTime createdAt;

  const ChatMessageModel({
    required this.id,
    required this.studentId,
    required this.doctorId,
    required this.senderId,
    required this.type,
    required this.createdAt,
    this.appointmentId,
    this.body,
    this.attachmentUrl,
    this.voiceDurationSeconds,
    this.readAt,
  });

  bool isFromMe(String currentUserId) => senderId == currentUserId;

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      doctorId: map['doctor_id'] as String,
      senderId: map['sender_id'] as String,
      appointmentId: map['appointment_id'] as String?,
      type: messageTypeFromString(map['message_type'] as String?),
      body: map['body'] as String?,
      attachmentUrl: map['attachment_url'] as String?,
      voiceDurationSeconds: map['voice_duration_seconds'] as int?,
      readAt: map['read_at'] != null
          ? DateTime.tryParse(map['read_at'] as String)
          : null,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'student_id': studentId,
    'doctor_id': doctorId,
    'sender_id': senderId,
    if (appointmentId != null) 'appointment_id': appointmentId,
    'message_type': messageTypeToString(type),
    if (body != null) 'body': body,
    if (attachmentUrl != null) 'attachment_url': attachmentUrl,
    if (voiceDurationSeconds != null)
      'voice_duration_seconds': voiceDurationSeconds,
  };
}
