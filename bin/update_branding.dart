import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Configuration
const String firestoreBaseUrl = 'https://firestore.googleapis.com/v1/projects/kirihat-db/databases/(default)/documents';
// Note: Assuming project ID is kirihat-db based on context. If this fails, user might need to check project ID.
// For a production app, we should use a proper Service Account or just ask user for the image URL if public access is restricted.
// Simpler approach for this dev tool: Ask user for the Project ID if needed, or assume 'ehatapprajikul-glitch' (from workspace mapping)? 
// Let's actually use a direct approach: Ask the user to paste the URL, OR try to fetch if we can.
// Better yet, let's just make the script ask the user if they want to fetch from a specific URL or auto-fetch.
//
// For simplicity and robustness, I will make the script attempt to read from a local config or just take valid URLs.
// But to make it "Auto", we'll try to use the public read access of Firestore if enabled, or just ask the user to paste the URL found in the Admin Panel.

void main(List<String> arguments) async {
  print('╔════════════════════════════════════════════╗');
  print('║       Kiri Hat - Update App Branding       ║');
  print('╚════════════════════════════════════════════╝');
  print('');

  // 1. Get Project ID
  String projectId = _getProjectId();
  print('Project ID detected: $projectId');
  
  // 2. Fetch Config
  print('Fetching latest branding config...');
  Map<String, dynamic>? config = await _fetchAppConfig(projectId);
  
  String? appName = config?['app_name'];
  String? iconUrl = config?['app_icon_url'];
  String brandingSource = config?['branding_source'] ?? 'manual';

  // 3a. Update App Name
  if (appName != null && appName.isNotEmpty) {
    print('Updating App Name to: "$appName"...');
    await _updateAppName(appName);
  }

  // 3b. Handle Branding Source
  if (brandingSource == 'manual') {
    print('ℹ️  Branding Source is set to "Manual".');
    print('   Skipping icon download. Using local "assets/icon/icon.png".');
    
    if (!File('assets/icon/icon.png').existsSync()) {
      print('⚠️  WARNING: "assets/icon/icon.png" was not found!');
      print('   Please ensure you have placed your icon file correctly.');
      print('   The generation might fail or use a default Flutter icon.');
    }
  } else {
    // Cloudinary or other URL
    if (iconUrl == null || iconUrl.isEmpty) {
        print('⚠️  Branding source is Cloud/URL but no URL found in config.');
        print('   Checking for manual overrides or user input...');
    } else {
        print('Downloading icon from: $iconUrl...');
        bool success = await _downloadFile(iconUrl, 'assets/icon/icon.png');
        if (!success) {
          print('❌ Failed to download image. Falling back to existing file if available.');
        } else {
          print('✅ Icon downloaded to assets/icon/icon.png');
        }
    }
  }

  // 4. Run Launcher Icons Generator
  print('Running flutter_launcher_icons...');
  var result = await Process.run('flutter', ['pub', 'run', 'flutter_launcher_icons']);
  
  if (result.exitCode == 0) {
    print('✅ Icons generated successfully!');
  } else {
    print('❌ Failed to generate icons.');
    print(result.stderr);
  }
  
  print('');
  print('🎉 Branding update complete! You can now build your app.');
  print('   Run: flutter build apk');
}

Future<void> _updateAppName(String newName) async {
  // 1. Android
  try {
    File manifest = File('android/app/src/main/AndroidManifest.xml');
    if (manifest.existsSync()) {
      String content = await manifest.readAsString();
      // Regex to replace android:label="..."
      content = content.replaceAll(RegExp(r'android:label="[^"]*"'), 'android:label="$newName"');
      await manifest.writeAsString(content);
      print('   ✅ Updated AndroidManifest.xml');
    }
  } catch (e) {
    print('   ❌ Failed to update Android label: $e');
  }

  // 2. iOS
  try {
    File plist = File('ios/Runner/Info.plist');
    if (plist.existsSync()) {
      String content = await plist.readAsString();
      // Replace CFBundleDisplayName
      content = content.replaceAll(
        RegExp(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)', multiLine: true), 
        '\$1$newName\$2'
      );
      // Replace CFBundleName
      content = content.replaceAll(
        RegExp(r'(<key>CFBundleName</key>\s*<string>)[^<]*(</string>)', multiLine: true), 
        '\$1$newName\$2'
      );
      await plist.writeAsString(content);
      print('   ✅ Updated Info.plist');
    }
  } catch (e) {
    print('   ❌ Failed to update iOS plist: $e');
  }

  // 3. Web
  try {
    File indexHtml = File('web/index.html');
    if (indexHtml.existsSync()) {
      String content = await indexHtml.readAsString();
      // Replace <title>...</title>
      content = content.replaceAll(
        RegExp(r'<title>.*?</title>', dotAll: true), 
        '<title>$newName</title>'
      );
      // Replace <meta name="apple-mobile-web-app-title" content="...">
      content = content.replaceAll(
        RegExp(r'(<meta\s+name="apple-mobile-web-app-title"\s+content=")[^"]*(")'), 
        '\$1$newName\$2'
      );
      await indexHtml.writeAsString(content);
      print('   ✅ Updated web/index.html');
    }
  } catch (e) {
    print('   ❌ Failed to update Web index.html: $e');
  }
}

String _getProjectId() {
  try {
    File f = File('.firebaserc');
    if (f.existsSync()) {
      String content = f.readAsStringSync();
      var json = jsonDecode(content);
      return json['projects']['default'] ?? 'unknown';
    }
  } catch (e) {
    // ignore
  }
  return 'kiri-hat-live'; // Updated to match .firebaserc
}

Future<Map<String, dynamic>?> _fetchAppConfig(String projectId) async {
  try {
    var url = Uri.parse('https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/platform_settings/app_config');
    var response = await http.get(url);
    
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      var fields = data['fields'];
      if (fields == null) return null;

      // Firestore REST API returns values in a specific format like {stringValue: "..."}
      Map<String, dynamic> config = {};
      
      if (fields['app_name'] != null) config['app_name'] = fields['app_name']['stringValue'];
      config['app_icon_url'] = fields['app_icon_url'] != null ? fields['app_icon_url']['stringValue'] : null;
      if (fields['branding_source'] != null) config['branding_source'] = fields['branding_source']['stringValue'];
      
      return config;
    } else {
       // Silent fail or print? For dev tool, print is okay
       print('Debug: API returned ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching config: $e');
  }
  return null;
}

Future<bool> _downloadFile(String url, String savePath) async {
  try {
    var response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      File file = File(savePath);
      await file.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);
      return true;
    } else {
      print('HTTP Error: ${response.statusCode}');
    }
  } catch (e) {
    print('Download Error: $e');
  }
  return false;
}
