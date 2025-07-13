// ignore_for_file: avoid_print, deprecated_member_use, library_private_types_in_public_api, use_build_context_synchronously
import 'package:chat/widgets/bottom_navigasi.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _currentIndex = 2;
  
  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  
  // Controllers for editing
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

   void _onNavigationItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
  
  Future<void> _loadUserData() async {
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      try {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .get();
        
        if (userDoc.exists) {
          setState(() {
            _userData = userDoc.data() as Map<String, dynamic>;
            _displayNameController.text = _userData!['displayName'] ?? '';
            _bioController.text = _userData!['bio'] ?? '';
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _updateProfile() async {
    if (_currentUser != null) {
      try {
        await _firestore.collection('users').doc(_currentUser!.uid).update({
          'displayName': _displayNameController.text,
          'bio': _bioController.text,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Update Firebase Auth display name
        await _currentUser!.updateDisplayName(_displayNameController.text);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload user data
        await _loadUserData();
      } catch (e) {
        print('Error updating profile: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _signOut() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF553C9A),
          title: Text(
            'Sign Out',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _auth.signOut();
                  Navigator.of(context).pushReplacementNamed('/login');
                } catch (e) {
                  print('Error signing out: $e');
                }
              },
              child: Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
  
  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF553C9A),
          title: Text(
            'Edit Profile',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _displayNameController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white70),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _bioController,
                style: TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white70),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateProfile();
              },
              child: Text(
                'Save',
                style: TextStyle(color: Colors.white),
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
        decoration: BoxDecoration(
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
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Column(
                  children: [
                    // Header
                    _buildHeader(),
                    
                    // Profile Content
                    Expanded(
                      
                      child: _buildProfileContent(),
                      
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
          
          
          // Title
          Expanded(
            child: Text(
              'Profile',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          
          // Edit Button
          GestureDetector(
            onTap: _showEditDialog,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.edit_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Profile Avatar and Info
          _buildProfileInfo(),
          
          SizedBox(height: 32),
          
          // Settings Options
          _buildSettingsOptions(),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Column(
      children: [
        // Avatar
        GestureDetector(
          onTap: () {},
          child: Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white.withOpacity(0.2),
                backgroundImage: (_userData?['photoURL'] != null && _userData!['photoURL'].isNotEmpty)
                    ? NetworkImage(_userData!['photoURL'])
                    : null,
                child: (_userData?['photoURL'] == null || _userData!['photoURL'].isEmpty)
                    ? Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.white,
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: 16,
                    color: Color(0xFF6B46C1),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        // Name
        Text(
          _userData?['displayName'] ?? 'Unknown User',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        
        SizedBox(height: 8),
        
        // Email
        Text(
          _currentUser?.email ?? '',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        
        SizedBox(height: 12),
        
        // Bio
        if (_userData?['bio'] != null && _userData!['bio'].isNotEmpty)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _userData!['bio'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }


  Widget _buildSettingsOptions() {
    return Column(
      children: [
        _buildSettingsItem(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          onTap: () {
            print('Notifications settings');
          },
        ),
        _buildSettingsItem(
          icon: Icons.security_outlined,
          title: 'Privacy & Security',
          onTap: () {
            print('Privacy settings');
          },
        ),
        _buildSettingsItem(
          icon: Icons.palette_outlined,
          title: 'Theme',
          onTap: () {
            print('Theme settings');
          },
        ),
        _buildSettingsItem(
          icon: Icons.help_outline,
          title: 'Help & Support',
          onTap: () {
            print('Help & Support');
          },
        ),
        _buildSettingsItem(
          icon: Icons.info_outline,
          title: 'About',
          onTap: () {
            print('About');
          },
        ),
        SizedBox(height: 16),
        _buildSettingsItem(
          icon: Icons.logout,
          title: 'Sign Out',
          onTap: _signOut,
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.white,
              size: 20,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: isDestructive ? Colors.red : Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isDestructive ? Colors.red : Colors.white.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}