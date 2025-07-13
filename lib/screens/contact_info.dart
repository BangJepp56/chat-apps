// ignore_for_file: avoid_print, deprecated_member_use, library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ContactInfoScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String recipientAvatar;
  final String chatId;

  const ContactInfoScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    required this.recipientAvatar,
    required this.chatId,
  });

  @override
  _ContactInfoScreenState createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends State<ContactInfoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Map<String, dynamic>? _userInfo;
  bool _isLoading = true;
  bool _isBlocked = false;
  bool _isMuted = false;
  String _lastSeen = '';
  int _totalMessages = 0;
  int _sharedMedia = 0;

  @override
  void initState() {
    super.initState();
    _loadContactInfo();
  }

  Future<void> _loadContactInfo() async {
    try {
      // Load user information
      final userDoc = await _firestore.collection('users').doc(widget.recipientId).get();
      
      if (userDoc.exists) {
        _userInfo = userDoc.data();
        
        // Load last seen
        final lastSeenTimestamp = _userInfo?['lastSeen'] as Timestamp?;
        if (lastSeenTimestamp != null) {
          _lastSeen = _formatLastSeen(lastSeenTimestamp);
        }
      }

      // Load chat statistics
      await _loadChatStats();
      
      // Check if user is blocked
      await _checkBlockStatus();
      
      // Check if chat is muted
      await _checkMuteStatus();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading contact info: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadChatStats() async {
    try {
      // Get total messages count
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .get();
      
      _totalMessages = messagesSnapshot.docs.length;
      
      // Count shared media (images, videos, documents)
      _sharedMedia = messagesSnapshot.docs.where((doc) {
        final data = doc.data();
        final messageType = data['messageType'] ?? 'text';
        return messageType != 'text';
      }).length;
    } catch (e) {
      print('Error loading chat stats: $e');
    }
  }

  Future<void> _checkBlockStatus() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final blockDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('blocked')
          .doc(widget.recipientId)
          .get();

      _isBlocked = blockDoc.exists;
    } catch (e) {
      print('Error checking block status: $e');
    }
  }

  Future<void> _checkMuteStatus() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final muteDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('muted')
          .doc(widget.recipientId)
          .get();

      _isMuted = muteDoc.exists;
    } catch (e) {
      print('Error checking mute status: $e');
    }
  }

  String _formatLastSeen(Timestamp timestamp) {
    final lastSeenTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(lastSeenTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('HH:mm').format(lastSeenTime)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(lastSeenTime);
    } else {
      return DateFormat('dd/MM/yyyy').format(lastSeenTime);
    }
  }

  Future<void> _blockUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      if (_isBlocked) {
        // Unblock user
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('blocked')
            .doc(widget.recipientId)
            .delete();
      } else {
        // Block user
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('blocked')
            .doc(widget.recipientId)
            .set({
          'blockedAt': FieldValue.serverTimestamp(),
          'userId': widget.recipientId,
          'userName': widget.recipientName,
        });
      }

      setState(() {
        _isBlocked = !_isBlocked;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isBlocked ? 'User blocked' : 'User unblocked'),
            backgroundColor: _isBlocked ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error blocking/unblocking user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _muteChat() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      if (_isMuted) {
        // Unmute chat
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('muted')
            .doc(widget.recipientId)
            .delete();
      } else {
        // Mute chat
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('muted')
            .doc(widget.recipientId)
            .set({
          'mutedAt': FieldValue.serverTimestamp(),
          'userId': widget.recipientId,
          'userName': widget.recipientName,
        });
      }

      setState(() {
        _isMuted = !_isMuted;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isMuted ? 'Chat muted' : 'Chat unmuted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error muting/unmuting chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearChat() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF4C1D95),
          title: const Text(
            'Clear Chat',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to clear all messages in this chat? This action cannot be undone.',
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
                  // Delete all messages in the chat
                  final messagesSnapshot = await _firestore
                      .collection('chats')
                      .doc(widget.chatId)
                      .collection('messages')
                      .get();

                  final batch = _firestore.batch();
                  for (var doc in messagesSnapshot.docs) {
                    batch.delete(doc.reference);
                  }

                  // Update chat document
                  batch.update(
                    _firestore.collection('chats').doc(widget.chatId),
                    {
                      'lastMessage': '',
                      'lastMessageTime': FieldValue.serverTimestamp(),
                      'lastMessageSender': '',
                    },
                  );

                  await batch.commit();

                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chat cleared'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error clearing chat: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
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
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Column(
                  children: [
                    // Header
                    _buildHeader(),
                    
                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Profile Section
                            _buildProfileSection(),
                            
                            const SizedBox(height: 24),
                            
                            // Quick Actions
                            _buildQuickActions(),
                            
                            const SizedBox(height: 24),
                            
                            // Info Section
                            _buildInfoSection(),
                            
                            const SizedBox(height: 24),
                            
                            // Settings Section
                            _buildSettingsSection(),
                            
                            const SizedBox(height: 24),
                            
                            // Danger Zone
                            _buildDangerZone(),
                          ],
                        ),
                      ),
                    ),
                  ],
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
          
          const SizedBox(width: 16),
          
          // Title
          const Text(
            'Contact Info',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Profile Picture
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white.withOpacity(0.2),
            backgroundImage: widget.recipientAvatar.isNotEmpty 
                ? NetworkImage(widget.recipientAvatar) 
                : null,
            child: widget.recipientAvatar.isEmpty
                ? const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 50,
                  )
                : null,
          ),
          
          const SizedBox(height: 16),
          
          // Name
          Text(
            widget.recipientName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Status/Last Seen
          Text(
            _userInfo?['isOnline'] == true ? 'Online' : 'Last seen $_lastSeen',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          
          if (_userInfo?['bio'] != null && _userInfo!['bio'].toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _userInfo!['bio'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.call,
          label: 'Audio',
          onTap: () {
            // TODO: Implement audio call
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Audio call feature coming soon'),
                backgroundColor: Colors.blue,
              ),
            );
          },
        ),
        _buildActionButton(
          icon: Icons.videocam,
          label: 'Video',
          onTap: () {
            // TODO: Implement video call
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video call feature coming soon'),
                backgroundColor: Colors.blue,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildInfoRow(
            icon: Icons.email,
            label: 'Email',
            value: _userInfo?['email'] ?? 'Not available',
          ),
          
          _buildInfoRow(
            icon: Icons.phone,
            label: 'Phone',
            value: _userInfo?['phone'] ?? 'Not available',
          ),
          
          _buildInfoRow(
            icon: Icons.calendar_today,
            label: 'Joined',
            value: _userInfo?['createdAt'] != null 
                ? DateFormat('MMM dd, yyyy').format((_userInfo!['createdAt'] as Timestamp).toDate())
                : 'Not available',
          ),
          
          _buildInfoRow(
            icon: Icons.message,
            label: 'Messages',
            value: '$_totalMessages',
          ),
          
          _buildInfoRow(
            icon: Icons.photo,
            label: 'Media',
            value: '$_sharedMedia',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white.withOpacity(0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: _isMuted ? Icons.volume_off : Icons.volume_up,
            title: _isMuted ? 'Unmute' : 'Mute',
            subtitle: _isMuted ? 'Receive notifications' : 'Stop notifications',
            onTap: _muteChat,
          ),
          
          _buildDivider(),
          
          _buildSettingTile(
            icon: Icons.wallpaper,
            title: 'Wallpaper',
            subtitle: 'Change chat background',
            onTap: () {
              // TODO: Implement wallpaper change
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Wallpaper feature coming soon'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
          
          _buildDivider(),
          
          _buildSettingTile(
            icon: Icons.photo_library,
            title: 'Media, links, and docs',
            subtitle: 'View shared content',
            onTap: () {
              // TODO: Implement media viewer
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Media viewer coming soon'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.clear,
            title: 'Clear Chat',
            subtitle: 'Delete all messages',
            onTap: _clearChat,
            isDestructive: true,
          ),
          
          _buildDivider(),
          
          _buildSettingTile(
            icon: _isBlocked ? Icons.person_add : Icons.block,
            title: _isBlocked ? 'Unblock' : 'Block',
            subtitle: _isBlocked ? 'Allow messages' : 'Stop receiving messages',
            onTap: _blockUser,
            isDestructive: !_isBlocked,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : Colors.white,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDestructive ? Colors.red.withOpacity(0.7) : Colors.white.withOpacity(0.7),
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.white.withOpacity(0.1),
      height: 1,
    );
  }
}