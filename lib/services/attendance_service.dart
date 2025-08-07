import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceService {
  static const String _attendanceKey = 'daily_attendance';

  Future<bool> signIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final attendanceData = {
        'date': today.toIso8601String(),
        'signInTime': now.toIso8601String(),
        'isSignedIn': true,
      };
      
      await prefs.setString(_attendanceKey, json.encode(attendanceData));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final attendanceString = prefs.getString(_attendanceKey);
      
      if (attendanceString != null) {
        final attendanceData = json.decode(attendanceString);
        attendanceData['signOutTime'] = now.toIso8601String();
        attendanceData['isSignedIn'] = false;
        
        await prefs.setString(_attendanceKey, json.encode(attendanceData));
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  Map<String, dynamic> getTodayAttendance() {
    try {
      // Mock data for now - in real app, get from SharedPreferences
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Return mock signed-in status
      return {
        'isSignedIn': false, // Change to true to test signed-in state
        'signInTime': '08:30 AM',
        'date': today.toIso8601String(),
      };
    } catch (e) {
      return {
        'isSignedIn': false,
        'signInTime': '',
        'date': DateTime.now().toIso8601String(),
      };
    }
  }
}
