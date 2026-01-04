import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  // Cloudinary credentials (using existing from master_product_form.dart)
  static const String cloudName = "du634o3sf";
  static const String uploadPreset = "ouofgw7n";
  
  /// Upload image to Cloudinary and return secure URL
  static Future<String?> uploadImage(Uint8List bytes, {String folder = "icons"}) async {
    try {
      var uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
      var request = http.MultipartRequest("POST", uri);
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: "${DateTime.now().millisecondsSinceEpoch}.jpg"
        )
      );
      
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folder;
      
      var response = await request.send();
      
      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var jsonMap = jsonDecode(String.fromCharCodes(responseData));
        return jsonMap['secure_url'];
      }
      
      print('❌ Cloudinary upload failed: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Error uploading to Cloudinary: $e');
      return null;
    }
  }
  
  /// Upload multiple images
  static Future<List<String>> uploadMultipleImages(List<Uint8List> imagesList) async {
    List<String> urls = [];
    
    for (var bytes in imagesList) {
      String? url = await uploadImage(bytes);
      if (url != null) {
        urls.add(url);
      }
    }
    
    return urls;
  }
}
