// ignore_for_file: avoid_print, deprecated_member_use, library_private_types_in_public_api, use_build_context_synchronously
import 'package:chat/screens/chat_room.dart';
import 'package:chat/widgets/bottom_navigasi.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchPage extends StatefulWidget {
  final Function(String)? onUserSelected;
  
  const SearchPage({
    super.key, 
    this.onUserSelected,
  });

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> recentSearches = [];
  bool isSearching = false;
  bool hasSearched = false;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Improved navigation handler
  void _onNavigationItemTapped(int index) {
    // Don't do anything here - let BottomNavigationWidget handle the navigation
    // This callback is just for state management if needed
  }

  void _loadRecentSearches() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data.containsKey('recentSearches')) {
          final List<dynamic> recent = data['recentSearches'] ?? [];
          setState(() {
            recentSearches = recent.cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (e) {
      print('Error loading recent searches: $e');
    }
  }

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        hasSearched = false;
        searchQuery = '';
      });
      return;
    }

    setState(() {
      isSearching = true;
      hasSearched = true;
      searchQuery = query;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Improved search logic
      final queryLower = query.toLowerCase();
      
      // Search by username - case insensitive
      final usernameQuery = await _firestore
          .collection('users')
          .orderBy('username')
          .startAt([queryLower])
          .endAt(['$queryLower\uf8ff'])
          .limit(20)
          .get();

      // Search by displayName - case insensitive
      final displayNameQuery = await _firestore
          .collection('users')
          .orderBy('displayName')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(20)
          .get();

      // Alternative search approach if the above doesn't work
      final allUsersQuery = await _firestore
          .collection('users')
          .limit(100)
          .get();

      final Map<String, Map<String, dynamic>> combinedResults = {};
      
      // Process username results
      for (var doc in usernameQuery.docs) {
        if (doc.id != currentUser.uid) {
          final data = doc.data();
          combinedResults[doc.id] = {
            'id': doc.id,
            'username': data['username'] ?? '',
            'displayName': data['displayName'] ?? '',
            'profilePicture': data['profilePicture'] ?? '',
            'isOnline': data['isOnline'] ?? false,
            'lastSeen': data['lastSeen'],
            'bio': data['bio'] ?? '',
          };
        }
      }

      // Process displayName results
      for (var doc in displayNameQuery.docs) {
        if (doc.id != currentUser.uid) {
          final data = doc.data();
          combinedResults[doc.id] = {
            'id': doc.id,
            'username': data['username'] ?? '',
            'displayName': data['displayName'] ?? '',
            'profilePicture': data['profilePicture'] ?? '',
            'isOnline': data['isOnline'] ?? false,
            'lastSeen': data['lastSeen'],
            'bio': data['bio'] ?? '',
          };
        }
      }

      // If no results from ordered queries, try client-side filtering
      if (combinedResults.isEmpty) {
        for (var doc in allUsersQuery.docs) {
          if (doc.id != currentUser.uid) {
            final data = doc.data();
            final username = (data['username'] ?? '').toString().toLowerCase();
            final displayName = (data['displayName'] ?? '').toString().toLowerCase();
            
            if (username.contains(queryLower) || displayName.contains(queryLower)) {
              combinedResults[doc.id] = {
                'id': doc.id,
                'username': data['username'] ?? '',
                'displayName': data['displayName'] ?? '',
                'profilePicture': data['profilePicture'] ?? '',
                'isOnline': data['isOnline'] ?? false,
                'lastSeen': data['lastSeen'],
                'bio': data['bio'] ?? '',
              };
              
              // Limit results to avoid too many
              if (combinedResults.length >= 20) break;
            }
          }
        }
      }

      setState(() {
        searchResults = combinedResults.values.toList();
        isSearching = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        isSearching = false;
      });
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching users: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addToRecentSearches(Map<String, dynamic> user) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Remove if already exists
      recentSearches.removeWhere((item) => item['id'] == user['id']);
      
      // Add to beginning
      recentSearches.insert(0, user);
      
      // Keep only last 10 searches
      if (recentSearches.length > 10) {
        recentSearches = recentSearches.take(10).toList();
      }

      // Save to Firestore
      await _firestore.collection('users').doc(currentUser.uid).set({
        'recentSearches': recentSearches,
      }, SetOptions(merge: true));

      setState(() {});
    } catch (e) {
      print('Error adding to recent searches: $e');
    }
  }

  void _clearRecentSearches() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore.collection('users').doc(currentUser.uid).set({
        'recentSearches': [],
      }, SetOptions(merge: true));

      setState(() {
        recentSearches = [];
      });
    } catch (e) {
      print('Error clearing recent searches: $e');
    }
  }

  void _onUserTap(Map<String, dynamic> user) {
    _addToRecentSearches(user);
    
    if (widget.onUserSelected != null) {
      widget.onUserSelected!(user['id']);
    } else {
      // Navigate to user profile or start chat
      _showUserOptionsDialog(user);
    }
  }

  void _showUserOptionsDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF553C9A),
        title: Text(
          user['displayName'],
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white.withOpacity(0.2),
              backgroundImage: user['profilePicture'].isNotEmpty
                  ? NetworkImage(user['profilePicture'])
                  : null,
              child: user['profilePicture'].isEmpty
                  ? Icon(Icons.person, color: Colors.white, size: 30)
                  : null,
            ),
            SizedBox(height: 12),
            Text(
              '@${user['username']}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            if (user['bio'].isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                user['bio'],
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.circle,
                  color: user['isOnline'] ? Colors.green : Colors.grey,
                  size: 8,
                ),
                SizedBox(width: 4),
                Text(
                  user['isOnline'] ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog first
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => ChatRoomMessage(
                    chatId: user['id'],
                    recipientId: user['id'],
                    recipientName: user['displayName'],
                    recipientAvatar: user['profilePicture'],
                  )
                )
              );
            },
            child: Text(
              'Start Chat',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSeen(dynamic lastSeen) {
    if (lastSeen == null) return 'Never';
    
    try {
      DateTime dateTime;
      if (lastSeen is Timestamp) {
        dateTime = lastSeen.toDate();
      } else {
        return 'Unknown';
      }
      
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays > 7) {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF6B46C1),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Search Users',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    // Add debounce to avoid too many requests
                    Future.delayed(Duration(milliseconds: 300), () {
                      if (_searchController.text == value) {
                        _searchUsers(value);
                      }
                    });
                  },
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by username or name...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Colors.white.withOpacity(0.6),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _searchUsers('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Content
            Expanded(
              child: _buildContent(),
            ),
            
            // Fixed Bottom Navigation - currentIndex set to 1 for Search
            BottomNavigationWidget(
              currentIndex: 1, // Always 1 for Search page
              onItemTapped: _onNavigationItemTapped,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isSearching) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (hasSearched) {
      return _buildSearchResults();
    }

    return _buildRecentSearches();
  }

  Widget _buildSearchResults() {
    if (searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try searching with a different keyword',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final user = searchResults[index];
        return _buildUserItem(user);
      },
    );
  }

  Widget _buildRecentSearches() {
    if (recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              'No recent searches',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start searching to see your recent searches here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Spacer(),
              TextButton(
                onPressed: _clearRecentSearches,
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: recentSearches.length,
            itemBuilder: (context, index) {
              final user = recentSearches[index];
              return _buildUserItem(user, isRecent: true);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user, {bool isRecent = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: InkWell(
        onTap: () => _onUserTap(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar with online indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    backgroundImage: user['profilePicture'].isNotEmpty
                        ? NetworkImage(user['profilePicture'])
                        : null,
                    child: user['profilePicture'].isEmpty
                        ? Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                  if (user['isOnline'])
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              
              SizedBox(width: 16),
              
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['displayName'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      '@${user['username']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user['bio'].isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        user['bio'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              // Status and actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isRecent)
                    Icon(
                      Icons.history,
                      color: Colors.white.withOpacity(0.6),
                      size: 16,
                    ),
                  SizedBox(height: 4),
                  Text(
                    user['isOnline'] ? 'Online' : _formatLastSeen(user['lastSeen']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}