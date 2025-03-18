import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

class AutoUpdate {
  static const String versionUrl = "http://126.209.7.246/V4/Others/Kurt/LatestVersionAPK/TagSearch/version.json";
  static const String apkUrl = "http://126.209.7.246/V4/Others/Kurt/LatestVersionAPK/TagSearch/tagSearch.apk";

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(versionUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> versionInfo = jsonDecode(response.body);
        final int latestVersionCode = versionInfo["versionCode"];
        final String latestVersionName = versionInfo["versionName"];
        final String releaseNotes = versionInfo["releaseNotes"];

        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        int currentVersionCode = int.parse(packageInfo.buildNumber);

        if (latestVersionCode > currentVersionCode) {
          _showUpdateDialog(context, latestVersionName, releaseNotes);
        }
      }
    } catch (e) {
      print("Error checking for update: $e");
    }
  }

  static void _showUpdateDialog(BuildContext context, String versionName, String releaseNotes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Update Available"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("New Version: $versionName"),
              SizedBox(height: 10),
              Text("Release Notes:"),
              Text(releaseNotes),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Later"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the update dialog
                _showDownloadProgressDialog(context); // Show the download progress dialog
                _downloadAndInstallApk(context); // Start the download process
              },
              child: Text("Update"),
            ),
          ],
        );
      },
    );
  }

  static void _showDownloadProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Downloading Update"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<int>(
                stream: _downloadProgressStream,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Column(
                      children: [
                        LinearProgressIndicator(
                          value: snapshot.data! / 100,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                        SizedBox(height: 10),
                        Text("${snapshot.data}% Downloading"),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        LinearProgressIndicator(
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                        SizedBox(height: 10),
                        Text("Starting download..."),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static Stream<int> get _downloadProgressStream async* {
    final request = http.Request('GET', Uri.parse(apkUrl));
    final http.StreamedResponse response = await request.send();

    int totalBytes = response.contentLength ?? 0;
    int downloadedBytes = 0;

    yield 0; // Start with 0%

    await for (var chunk in response.stream) {
      downloadedBytes += chunk.length;
      int progress = ((downloadedBytes / totalBytes) * 100).round();
      yield progress; // Yield the progress percentage
    }

    yield 100; // Complete at 100%
  }

  static Future<void> _downloadAndInstallApk(BuildContext context) async {
    try {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final String apkPath = "${externalDir.path}/tagSearch.apk";
        final File apkFile = File(apkPath);

        final request = http.Request('GET', Uri.parse(apkUrl));
        final http.StreamedResponse response = await request.send();

        if (response.statusCode == 200) {
          final fileSink = apkFile.openWrite();
          await response.stream.pipe(fileSink);
          await fileSink.close();

          if (await apkFile.exists()) {
            _installApk(context, apkPath); // Install the APK after download
          } else {
            Fluttertoast.showToast(msg: "Failed to save the APK file.");
          }
        }
      }
    } catch (e) {
      print("Error downloading APK: $e");
      Fluttertoast.showToast(msg: "Failed to download update.");
    } finally {
      Navigator.of(context).pop(); // Close the download progress dialog
    }
  }

  static void _installApk(BuildContext context, String apkPath) async {
    try {
      if (await Permission.requestInstallPackages.isGranted) {
        final result = await OpenFile.open(apkPath);
        if (result.type != ResultType.done) {
          Fluttertoast.showToast(msg: "Failed to open the installer.");
        }
      } else {
        await Permission.requestInstallPackages.request();
        if (await Permission.requestInstallPackages.isGranted) {
          final result = await OpenFile.open(apkPath);
          if (result.type != ResultType.done) {
            Fluttertoast.showToast(msg: "Failed to open the installer.");
          }
        } else {
          Fluttertoast.showToast(msg: "Installation permission denied.");
        }
      }
    } catch (e) {
      print("Error installing APK: $e");
      Fluttertoast.showToast(msg: "Failed to install update.");
    }
  }
}

