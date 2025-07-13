// ignore_for_file: avoid_print, deprecated_member_use, library_private_types_in_public_api, use_build_context_synchronously

import 'package:chat/screens/contact_info.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChatRoomMessage extends StatefulWidget {
  final String chatId;
  final String recipientId;
  final String recipientName;
  final String recipientAvatar;

  const ChatRoomMessage({
    super.key,
    required this.chatId,
    required this.recipientId,
    required this.recipientName,
    required this.recipientAvatar,
  });
  
  @override
  _ChatRoomState createState() => _ChatRoomState();
}

class _ChatRoomState extends State<ChatRoomMessage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  Stream<QuerySnapshot>? _messagesStream;
  bool _isLoading = false;
  bool _isTyping = false;
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    _initializeChat();
  }
  
  Future<void> _initializeChat() async {
    try {
      // Pastikan Firebase Auth sudah siap
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        // Jika tidak ada user yang login, kembali ke halaman sebelumnya
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }
      
      // Cek apakah chatId valid
      if (widget.chatId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid chat ID'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }
      
      // Inisialisasi stream dengan error handling
      await _initializeMessagesStream();
      
      // Mark messages as read setelah stream diinisialisasi
      await _markMessagesAsRead();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _initializeMessagesStream() async {
    try {
      // Pastikan chat document ada
      final chatDoc = await _firestore.collection('chats').doc(widget.chatId).get();
      
      if (!chatDoc.exists) {
        // Jika chat tidak ada, buat chat baru
        await _firestore.collection('chats').doc(widget.chatId).set({
          'participants': [_auth.currentUser?.uid, widget.recipientId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSender': '',
        });
      }
      
      _messagesStream = _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots();
          
    } catch (e) {
      print('Error initializing messages stream: $e');
      rethrow;
    }
  }
  
  Future<void> _markMessagesAsRead() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      
      final unreadMessages = await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      if (unreadMessages.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }
  
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    final messageText = _messageController.text.trim();
    _messageController.clear();
    
    try {
      // Batch write untuk konsistensi
      final batch = _firestore.batch();
      
      // Add message to subcollection
      final messageRef = _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc();
          
      batch.set(messageRef, {
        'senderId': currentUser.uid,
        'receiverId': widget.recipientId,
        'message': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'messageType': 'text',
      });
      
      // Update last message in chat document
      final chatRef = _firestore.collection('chats').doc(widget.chatId);
      batch.update(chatRef, {
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUser.uid,
      });
      
      await batch.commit();
      
      // Scroll to bottom
      _scrollToBottom();
      
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }
  
  String _formatMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    try {
      final messageTime = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(messageTime);
      
      if (difference.inDays == 0) {
        return DateFormat('HH:mm').format(messageTime);
      } else if (difference.inDays == 1) {
        return 'Yesterday ${DateFormat('HH:mm').format(messageTime)}';
      } else if (difference.inDays < 7) {
        return DateFormat('EEEE HH:mm').format(messageTime);
      } else {
        return DateFormat('dd/MM/yyyy HH:mm').format(messageTime);
      }
    } catch (e) {
      print('Error formatting time: $e');
      return '';
    }
  }
  
  void _deleteMessage(String messageId) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF4C1D95),
          title: const Text(
            'Delete Message',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete this message?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _firestore
                      .collection('chats')
                      .doc(widget.chatId)
                      .collection('messages')
                      .doc(messageId)
                      .delete();
                  
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message deleted'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting message: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6B46C1), // Purple-600
              Color(0xFF553C9A), // Purple-700
              Color(0xFF4C1D95), // Purple-800
            ],
          ),
        ),
        child: SafeArea(
          child: _isInitialized
              ? Column(
                  children: [
                    // Header
                    _buildHeader(),
                    
                    // Messages List
                    Expanded(
                      child: _buildMessagesList(),
                    ),
                    
                    // Message Input
                    _buildMessageInput(),
                  ],
                )
              : const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // User Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withOpacity(0.2),
            backgroundImage: widget.recipientAvatar.isNotEmpty 
                ? NetworkImage(widget.recipientAvatar) 
                : null,
            child: widget.recipientAvatar.isEmpty
                ? const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  )
                : null,
          ),
          
          const SizedBox(width: 12),
          
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.recipientName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Online', // You can implement actual online status
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          
          // More Options
          GestureDetector(
            onTap: () {
              _showMoreOptions();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.more_vert,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessagesList() {
    if (_messagesStream == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }
        
        if (snapshot.hasError) {
          print('StreamBuilder error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.white.withOpacity(0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading messages',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    _initializeChat();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.white.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start the conversation!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final messageDoc = snapshot.data!.docs[index];
            final messageData = messageDoc.data() as Map<String, dynamic>?;
            
            if (messageData == null) {
              return const SizedBox.shrink();
            }
            
            return _buildMessageBubble(
              messageDoc.id,
              messageData,
            );
          },
        );
      },
    );
  }
  
  Widget _buildMessageBubble(String messageId, Map<String, dynamic> messageData) {
    final currentUser = _auth.currentUser;
    final isMe = messageData['senderId'] == currentUser?.uid;
    final message = messageData['message']?.toString() ?? '';
    final timestamp = messageData['timestamp'] as Timestamp?;
    final isRead = messageData['isRead'] ?? false;
    
    return GestureDetector(
      onLongPress: isMe ? () => _deleteMessage(messageId) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.white.withOpacity(0.2),
                backgroundImage: widget.recipientAvatar.isNotEmpty 
                    ? NetworkImage(widget.recipientAvatar) 
                    : null,
                child: widget.recipientAvatar.isEmpty
                    ? const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 12,
                      )
                    : null,
              ),
              const SizedBox(width: 8),
            ],
            
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isMe 
                      ? Colors.white.withOpacity(0.9)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        color: isMe ? Colors.black87 : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatMessageTime(timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe 
                                ? Colors.black54 
                                : Colors.white.withOpacity(0.6),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            isRead ? Icons.done_all : Icons.done,
                            size: 12,
                            color: isRead ? Colors.blue : Colors.grey,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            if (isMe) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.white.withOpacity(0.2),
                backgroundImage: currentUser?.photoURL != null 
                    ? NetworkImage(currentUser!.photoURL!) 
                    : null,
                child: currentUser?.photoURL == null
                    ? const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 12,
                      )
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Attachment Button
          GestureDetector(
            onTap: () {
              _showAttachmentOptions();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.attach_file,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Message Input Field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  if (mounted) {
                    setState(() {
                      _isTyping = value.isNotEmpty;
                    });
                  }
                },
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _sendMessage();
                  }
                },
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Send Button
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isTyping 
                    ? Colors.white.withOpacity(0.9)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      Icons.send,
                      color: _isTyping ? Colors.black87 : Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showMoreOptions() {
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF4C1D95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.call, color: Colors.white),
              title: const Text('Voice Call', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement voice call
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white),
              title: const Text('Video Call', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement video call
              },
            ),
            ListTile(
              leading: const Icon(Icons.info, color: Colors.white),
              title: const Text('Contact Info', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => ContactInfoScreen(
                    recipientId: widget.recipientId,
                    recipientName: widget.recipientName,
                    recipientAvatar: widget.recipientAvatar,
                    chatId: widget.chatId,
                  ),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Block User', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Block user
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showAttachmentOptions() {
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF4C1D95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Open camera
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Open gallery
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Colors.white),
              title: const Text('Document', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Open file picker
              },
            ),
          ],
        ),
      ),
    );
  }
}