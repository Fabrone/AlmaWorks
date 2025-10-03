import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

/// Mobile/Desktop implementation for file downloads
/// This prompts the user to select a directory and saves the file there
Future<String?> downloadFile(Uint8List bytes, String fileName) async {
  try {
    // Prompt user to select a directory
    final String? selectedDir = await FilePicker.platform.getDirectoryPath();
    
    // User cancelled the selection
    if (selectedDir == null) {
      return null;
    }
    
    // Create full file path
    final savePath = path.join(selectedDir, fileName);
    
    // Write bytes to file
    final file = File(savePath);
    await file.writeAsBytes(bytes);
    
    // Return the full path where file was saved
    return savePath;
  } catch (e) {
    throw Exception('Mobile download failed: $e');
  }
}