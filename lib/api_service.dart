import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const List<String> apiUrls = [
    "http://192.168.254.163/",
    "http://126.209.7.246/"
  ];

  static const Duration requestTimeout = Duration(seconds: 2);

  Future<http.Response> _makeRequest(Uri uri, {Map<String, String>? headers, Object? body}) async {
    try {
      final response = await http.get(uri, headers: headers).timeout(requestTimeout);
      return response;
    } on TimeoutException {
      throw Exception("Request timed out");
    } catch (e) {
      throw Exception("Failed to make request: $e");
    }
  }

  Future<String> fetchSoftwareLink(int linkID) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? idNumber = prefs.getString('IDNumber');

    for (String apiUrl in apiUrls) {
      try {
        final uri = Uri.parse("${apiUrl}V4/Others/Kurt/ArkLinkAPI/kurt_fetchLink.php?linkID=$linkID");
        final response = await _makeRequest(uri);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data.containsKey("softwareLink")) {
            String relativePath = data["softwareLink"];
            String fullUrl = Uri.parse(apiUrl).resolve(relativePath).toString();
            if (idNumber != null) {
              fullUrl += "?idNumber=$idNumber";
            }
            return fullUrl;
          } else {
            throw Exception(data["error"]);
          }
        }
      } catch (e) {
        print("Error accessing $apiUrl: $e");
      }
    }
    throw Exception("Both API URLs are unreachable");
  }

  Future<bool> checkIdNumber(String idNumber) async {
    for (String apiUrl in apiUrls) {
      try {
        final uri = Uri.parse("${apiUrl}V4/Others/Kurt/ArkLinkAPI/kurt_checkIdNumber.php");
        final response = await http.post(
          uri,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"idNumber": idNumber}),
        ).timeout(requestTimeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data["success"] == true) {
            return true;
          } else {
            throw Exception(data["message"]);
          }
        }
      } catch (e) {
        print("Error accessing $apiUrl: $e");
      }
    }
    throw Exception("Both API URLs are unreachable");
  }

  Future<Map<String, dynamic>> fetchProfile(String idNumber) async {
    for (String apiUrl in apiUrls) {
      try {
        final uri = Uri.parse("${apiUrl}V4/Others/Kurt/ArkLinkAPI/kurt_fetchProfile.php?idNumber=$idNumber");
        final response = await _makeRequest(uri);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data["success"] == true) {
            return data;
          } else {
            throw Exception(data["message"]);
          }
        }
      } catch (e) {
        print("Error accessing $apiUrl: $e");
      }
    }
    throw Exception("Both API URLs are unreachable");
  }

  Future<void> updateLanguageFlag(String idNumber, int languageFlag) async {
    for (String apiUrl in apiUrls) {
      try {
        final uri = Uri.parse("${apiUrl}V4/Others/Kurt/ArkLinkAPI/kurt_updateLanguage.php");
        final response = await http.post(
          uri,
          body: {
            'idNumber': idNumber,
            'languageFlag': languageFlag.toString(),
          },
        ).timeout(requestTimeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data["success"] == true) {
            return;
          } else {
            throw Exception(data["message"]);
          }
        }
      } catch (e) {
        print("Error accessing $apiUrl: $e");
      }
    }
    throw Exception("Both API URLs are unreachable");
  }
}