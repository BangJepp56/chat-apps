// ignore_for_file: avoid_print, deprecated_member_use, library_private_types_in_public_api, use_build_context_synchronously, unused_element

import 'package:chat/models/chat.dart';
import 'package:chat/widgets/bottom_navigasi.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'search.dart';
import 'package:chat/screens/chat_room.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  _MessagesPageState createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  int _currentIndex = 0;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final ValueNotifier<List<ChatMessage>> _messagesNotifier = ValueNotifier<List<ChatMessage>>([]);
  
  // Cache for user data to avoid repeated Firestore calls
  final Map<String, Map<String, dynamic>> _userCache = {};
  
  @override
  void initState() {
    super.initState();
    _initializeMessagesStream();
  }
  
  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messagesNotifier.dispose();
    super.dispose();
  }
  
  void _initializeMessagesStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _setError('No authenticated user found');
      return;
    }
    
    _setLoading(true);
    _messagesSubscription?.cancel();
    
    // FIX 1: Use a simpler query without orderBy first
    _messagesSubscription = _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .snapshots()
        .listen(
      (snapshot) => _handleChatsSnapshot(snapshot, currentUser.uid),
      onError: (error) {
        debugPrint('Firestore error: $error');
        _setError('Failed to load messages: $error');
      },
    );
  }
  
  Future<void> _handleChatsSnapshot(QuerySnapshot snapshot, String currentUserId) async {
    try {
      debugPrint('Received ${snapshot.docs.length} chat documents');
      
      if (snapshot.docs.isEmpty) {
        _messagesNotifier.value = [];
        _setLoading(false);
        return;
      }
      
      final messages = await _processChatsData(snapshot.docs, currentUserId);
      debugPrint('Processed ${messages.length} messages');
      _messagesNotifier.value = messages;
      _setLoading(false);
      _clearError();
    } catch (e) {
      debugPrint('Error in _handleChatsSnapshot: $e');
      _setError('Error processing messages: $e');
    }
  }
  
  Future<List<ChatMessage>> _processChatsData(
    List<QueryDocumentSnapshot> docs,
    String currentUserId,
  ) async {
    final List<ChatMessage> messages = [];
    
    // FIX 2: Process all chats at once instead of batching
    for (final doc in docs) {
      try {
        debugPrint('Processing chat: ${doc.id}');
        final message = await _processSingleChat(doc, currentUserId);
        if (message != null) {
          messages.add(message);
          debugPrint('Added message from: ${message.name}');
        } else {
          debugPrint('Skipped chat: ${doc.id} (invalid data)');
        }
      } catch (e) {
        debugPrint('Error processing chat ${doc.id}: $e');
        // Continue processing other chats
      }
    }
    
    // FIX 3: Sort by timestamp, handle null values properly
    messages.sort((a, b) {
      final aTime = a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    
    return messages;
  }
  
  Future<ChatMessage?> _processSingleChat(
    QueryDocumentSnapshot doc,
    String currentUserId,
  ) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      
      debugPrint('Chat data for ${doc.id}: $data');
      
      if (!_isValidChatData(data)) {
        debugPrint('Invalid chat data for ${doc.id}');
        return null;
      }
      
      final participants = List<String>.from(data['participants'] ?? []);
      debugPrint('Participants: $participants');
      
      final otherUserId = participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      
      if (otherUserId.isEmpty) {
        debugPrint('No other user found for chat ${doc.id}');
        return null;
      }
      
      debugPrint('Other user ID: $otherUserId');
      
      final userData = await _getUserData(otherUserId);
      final unreadCount = await _getUnreadMessageCount(doc.id, currentUserId);
      
      // FIX 4: Handle missing or null lastMessageTime
      final lastMessageTime = data['lastMessageTime'];
      DateTime? actualTime;
      
      if (lastMessageTime is Timestamp) {
        actualTime = lastMessageTime.toDate();
      } else if (lastMessageTime is DateTime) {
        actualTime = lastMessageTime;
      } else {
        // If no timestamp, use current time or document creation time
        actualTime = DateTime.now();
        debugPrint('No lastMessageTime found for chat ${doc.id}, using current time');
      }
      
      final message = ChatMessage(
        chatId: doc.id,
        name: userData['displayName'] ?? 'Unknown User',
        message: data['lastMessage'] ?? 'No messages yet',
        time: _formatTime(actualTime),
        avatar: userData['photoURL'] ?? '',
        userId: otherUserId,
        unreadCount: unreadCount,
        lastMessageSender: data['lastMessageSender'] ?? '',
        lastMessageTime: actualTime,
      );
      
      debugPrint('Created message: ${message.name} - ${message.message}');
      return message;
    } catch (e) {
      debugPrint('Error in _processSingleChat for ${doc.id}: $e');
      return null;
    }
  }
  
  bool _isValidChatData(Map<String, dynamic> data) {
    // FIX 5: More lenient validation
    final hasParticipants = data['participants'] != null && 
                           data['participants'] is List && 
                           (data['participants'] as List).length >= 2;
    
    if (!hasParticipants) {
      debugPrint('Invalid participants: ${data['participants']}');
    }
    
    return hasParticipants;
  }
  
  Future<Map<String, dynamic>> _getUserData(String userId) async {
    // Check cache first
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }
    
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 10));
      
      if (userDoc.exists) {
        final userData = userDoc.data() ?? {};
        _userCache[userId] = userData;
        debugPrint('User data for $userId: $userData');
        return userData;
      } else {
        debugPrint('User document not found for $userId');
      }
    } catch (e) {
      debugPrint('Error fetching user data for $userId: $e');
    }
    
    // Return default data if user not found or error occurs
    final defaultData = {
      'displayName': 'Unknown User',
      'photoURL': '',
    };
    _userCache[userId] = defaultData;
    return defaultData;
  }
  
  Future<int> _getUnreadMessageCount(String chatId, String currentUserId) async {
    try {
      final unreadMessages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .limit(100)
          .get()
          .timeout(const Duration(seconds: 5));
      
      return unreadMessages.docs.length;
    } catch (e) {
      debugPrint('Error getting unread count for $chatId: $e');
      return 0;
    }
  }
  
  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return '';
    
    try {
      final now = DateTime.now();
      final difference = now.difference(timestamp);
      
      if (difference.inMinutes < 1) {
        return 'now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d';
      } else {
        return DateFormat('MMM dd').format(timestamp);
      }
    } catch (e) {
      debugPrint('Error formatting time: $e');
      return '';
    }
  }
  
  void _setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
      });
    }
  }
  
  void _setError(String message) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }
  
  void _clearError() {
    if (mounted) {
      setState(() {
        _hasError = false;
        _errorMessage = '';
      });
    }
  }
  
  void _onNavigationItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
  
  void _startNewChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SearchPage(),
      ),
    );
  }
  
  void _openChat(ChatMessage message) {
    if (message.chatId.isEmpty || message.userId.isEmpty) {
      _showErrorSnackBar('Invalid chat data');
      return;
    }
    
    // Mark messages as read when entering chat
    _markMessagesAsRead(message.chatId);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomMessage(
          chatId: message.chatId,
          recipientId: message.userId,
          recipientName: message.name,
          recipientAvatar: message.avatar,
        ),
      ),
    ).then((_) {
      // Refresh the messages list when returning from chat
      _refreshMessages();
    });
  }
  
  Future<void> _markMessagesAsRead(String chatId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      
      final unreadMessages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      if (unreadMessages.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  void _deleteChat(ChatMessage message) {
    if (message.chatId.isEmpty) {
      _showErrorSnackBar('Invalid chat ID');
      return;
    }
    
    _showDeleteConfirmationDialog(message);
  }
  
  void _showDeleteConfirmationDialog(ChatMessage message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF4C1D95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Chat',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this chat with ${message.name}?',
            style: const TextStyle(color: Colors.white70),
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
                Navigator.of(context).pop();
                await _performDeleteChat(message.chatId);
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
  
  Future<void> _performDeleteChat(String chatId) async {
    try {
      _showLoadingDialog('Deleting chat...');
      
      // Use batch write for better performance
      _firestore.batch();
      
      // Delete messages in smaller batches to avoid timeout
      bool hasMoreMessages = true;
      while (hasMoreMessages) {
        final messagesQuery = await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .limit(100)
            .get();
        
        if (messagesQuery.docs.isEmpty) {
          hasMoreMessages = false;
        } else {
          final deleteBatch = _firestore.batch();
          for (final doc in messagesQuery.docs) {
            deleteBatch.delete(doc.reference);
          }
          await deleteBatch.commit();
        }
      }
      
      // Delete the chat document
      await _firestore.collection('chats').doc(chatId).delete();
      
      // Clear user cache for this chat
      _userCache.clear();
      
      if (mounted) {
        Navigator.of(context).pop();
        _showSuccessSnackBar('Chat deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showErrorSnackBar('Failed to delete chat: ${e.toString()}');
      }
    }
  }
  
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
  
  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
  
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF4C1D95),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Future<void> _refreshMessages() async {
    if (_isLoading) return;
    
    // Clear cache to force fresh data
    _userCache.clear();
    
    _initializeMessagesStream();
    
    // Add a small delay for better UX
    await Future.delayed(const Duration(milliseconds: 500));
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
              Color(0xFF6B46C1),
              Color(0xFF553C9A),
              Color(0xFF4C1D95),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _buildMessagesList(),
              ),
              BottomNavigationWidget(
                currentIndex: _currentIndex,
                onItemTapped: _onNavigationItemTapped,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chat_bubble_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          
          const Expanded(
            child: Text(
              'Messages',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          
          _buildHeaderButton(
            icon: Icons.search,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SearchPage(),
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          _buildHeaderButton(
            icon: Icons.edit_outlined,
            onTap: _startNewChat,
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ValueListenableBuilder<List<ChatMessage>>(
        valueListenable: _messagesNotifier,
        builder: (context, messages, child) {
          if (_isLoading && messages.isEmpty) {
            return _buildLoadingState();
          }
          
          if (_hasError && messages.isEmpty) {
            return _buildErrorState();
          }
          
          if (messages.isEmpty) {
            return _buildEmptyState();
          }
          
          return RefreshIndicator(
            key: _refreshIndicatorKey,
            onRefresh: _refreshMessages,
            backgroundColor: Colors.white.withOpacity(0.9),
            color: const Color(0xFF6B46C1),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return _buildMessageItem(messages[index]);
              },
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          SizedBox(height: 16),
          Text(
            'Loading messages...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorState() {
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
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage.isNotEmpty ? _errorMessage : 'Please check your internet connection',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshMessages,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
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
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new conversation',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _startNewChat,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Start New Chat'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    final currentUser = _auth.currentUser;
    final isLastMessageFromMe = message.lastMessageSender == currentUser?.uid;
    
    return GestureDetector(
      onTap: () => _openChat(message),
      onLongPress: () => _deleteChat(message),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _buildAvatar(message),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMessageContent(message, isLastMessageFromMe),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAvatar(ChatMessage message) {
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 2,
            ),
          ),
          child: message.avatar.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    message.avatar,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultAvatar(message.name);
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildDefaultAvatar(message.name);
                    },
                  ),
                )
              : _buildDefaultAvatar(message.name),
        ),
        if (message.unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                message.unreadCount > 99 ? '99+' : message.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildDefaultAvatar(String name) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.2),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  Widget _buildMessageContent(ChatMessage message, bool isLastMessageFromMe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                message.name.isEmpty ? 'Unknown User' : message.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (message.time.isNotEmpty)
              Text(
                message.time,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (isLastMessageFromMe) ...[
              Icon(
                Icons.done_all,
                size: 16,
                color: Colors.white.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                message.message.isEmpty ? 'No message' : message.message,
                style: TextStyle(
                  fontSize: 14,
                  color: message.unreadCount > 0 && !isLastMessageFromMe
                      ? Colors.white.withOpacity(0.9)
                      : Colors.white.withOpacity(0.6),
                  fontWeight: message.unreadCount > 0 && !isLastMessageFromMe
                      ? FontWeight.w500
                      : FontWeight.normal,
                  fontStyle: message.message.isEmpty 
                      ? FontStyle.italic 
                      : FontStyle.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}