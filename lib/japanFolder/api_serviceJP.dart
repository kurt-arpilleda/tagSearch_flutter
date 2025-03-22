import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const List<String> apiUrls = [
    "http://192.168.1.213/",
    "http://220.157.175.232/"
  ];

  static const Duration requestTimeout = Duration(seconds: 2);

  Future<http.Response> _makeRequest(Uri uri, {Map<String, String>? headers, int retries = 5}) async {
    for (int attempt = 1; attempt <= retries; attempt++) {
      for (String apiUrl in apiUrls) {
        try {
          final fullUri = Uri.parse(apiUrl).resolve(uri.toString());
          final response = await http.get(fullUri, headers: headers).timeout(requestTimeout);
          return response;
        } catch (e) {
          print("Error accessing $apiUrl on attempt $attempt: $e");
        }
      }
      // If all servers fail, wait for a short delay before retrying
      if (attempt < retries) {
        await Future.delayed(Duration(seconds: 2));
      }
    }
    throw Exception("All API URLs are unreachable after $retries attempts");
  }

  Future<String> fetchSoftwareLink(int linkID) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? idNumber = prefs.getString('IDNumberJP');

    for (String apiUrl in apiUrls) {
      try {
        final uri = Uri.parse("${apiUrl}V4/Others/Kurt/ArkLinkAPI/kurt_fetchLink.php?linkID=$linkID");
        final response = await http.get(uri).timeout(requestTimeout);

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
        final response = await http.get(uri).timeout(requestTimeout);

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
