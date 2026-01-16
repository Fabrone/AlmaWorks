// welcome_screen.dart
import 'package:almaworks/authentication/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class WelcomeScreen extends StatefulWidget {
  final String username;
  final String initialRole;

  const WelcomeScreen({super.key, required this.username, required this.initialRole});

  @override
  WelcomeScreenState createState() => WelcomeScreenState();
}

class WelcomeScreenState extends State<WelcomeScreen> {
  String _currentRole = '';
  StreamSubscription<DocumentSnapshot>? _roleSubscription;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.initialRole;
    _setupRoleListener();
  }

  void _setupRoleListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Redirect to login if no user
      Navigator.pushReplacementNamed(context, '/login'); // Assume route setup in main.dart
      return;
    }

    // Listen to the specific document by username (doc ID)
    _roleSubscription = FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.username)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data();
          final newRole = data?['role'] as String? ?? 'Client';
          if (newRole != _currentRole) {
            setState(() {
              _currentRole = newRole;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Your role has been updated to $newRole')),
            );
          }
        } else {
          // Handle missing doc
          setState(() {
            _currentRole = 'Client';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User data not found. Defaulting to Client.')),
          );
        }
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error listening to role: $error')),
        );
      },
    );
  }

  @override
  void dispose() {
    _roleSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome, ${widget.username}!',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'You are logged in as $_currentRole.',
                style: const TextStyle(
                  fontSize: 22,
                  fontStyle: FontStyle.italic,
                  color: Color.fromARGB(255, 73, 98, 110),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Logout', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}