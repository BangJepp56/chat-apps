class ChatMessage {
  final String chatId;
  final String name;
  final String message;
  final String time;
  final String avatar;
  final String userId;
  final int unreadCount;
  final String lastMessageSender;
  final DateTime? lastMessageTime; // Added for proper sorting

  ChatMessage({
    required this.chatId,
    required this.name,
    required this.message,
    required this.time,
    required this.avatar,
    required this.userId,
    required this.unreadCount,
    required this.lastMessageSender,
    this.lastMessageTime,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'name': name,
      'message': message,
      'time': time,'avatar': avatar,
     'userId': userId,
     'unreadCount': unreadCount,
     'lastMessageSender': lastMessageSender,
     'lastMessageTime': lastMessageTime?.toIso8601String(),
   };
 }

 // Create from Map (Firestore data)
 factory ChatMessage.fromMap(Map<String, dynamic> map) {
   return ChatMessage(
     chatId: map['chatId'] ?? '',
     name: map['name'] ?? '',
     message: map['message'] ?? '',
     time: map['time'] ?? '',
     avatar: map['avatar'] ?? '',
     userId: map['userId'] ?? '',
     unreadCount: map['unreadCount'] ?? 0,
     lastMessageSender: map['lastMessageSender'] ?? '',
     lastMessageTime: map['lastMessageTime'] != null 
         ? DateTime.parse(map['lastMessageTime']) 
         : null,
   );
 }

 // Copy with method for updating specific fields
 ChatMessage copyWith({
   String? chatId,
   String? name,
   String? message,
   String? time,
   String? avatar,
   String? userId,
   int? unreadCount,
   String? lastMessageSender,
   DateTime? lastMessageTime,
 }) {
   return ChatMessage(
     chatId: chatId ?? this.chatId,
     name: name ?? this.name,
     message: message ?? this.message,
     time: time ?? this.time,
     avatar: avatar ?? this.avatar,
     userId: userId ?? this.userId,
     unreadCount: unreadCount ?? this.unreadCount,
     lastMessageSender: lastMessageSender ?? this.lastMessageSender,
     lastMessageTime: lastMessageTime ?? this.lastMessageTime,
   );
 }

 @override
 String toString() {
   return 'ChatMessage(chatId: $chatId, name: $name, message: $message, time: $time, avatar: $avatar, userId: $userId, unreadCount: $unreadCount, lastMessageSender: $lastMessageSender, lastMessageTime: $lastMessageTime)';
 }

 @override
 bool operator ==(Object other) {
   if (identical(this, other)) return true;
   return other is ChatMessage &&
       other.chatId == chatId &&
       other.name == name &&
       other.message == message &&
       other.time == time &&
       other.avatar == avatar &&
       other.userId == userId &&
       other.unreadCount == unreadCount &&
       other.lastMessageSender == lastMessageSender &&
       other.lastMessageTime == lastMessageTime;
 }

 @override
 int get hashCode {
   return chatId.hashCode ^
       name.hashCode ^
       message.hashCode ^
       time.hashCode ^
       avatar.hashCode ^
       userId.hashCode ^
       unreadCount.hashCode ^
       lastMessageSender.hashCode ^
       lastMessageTime.hashCode;
 }
}