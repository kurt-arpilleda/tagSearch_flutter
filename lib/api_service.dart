import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const List<String> apiUrls = [
    "http://126.209.7.246/",
    "http://192.168.254.163/"
  ];

  Future<String> fetchSoftwareLink(int linkID) async {
    // Get the ID number from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? idNumber = prefs.getString('IDNumber');

    for (String apiUrl in apiUrls) {
      try {
        final response = await http.get(Uri.parse("${apiUrl}V4/Others/Kurt/ArkLinkAPI/kurt_fetchLink.php?linkID=$linkID"));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data.containsKey("softwareLink")) {
            // If the returned softwareLink is a relative path, prepend the base URL
            String relativePath = data["softwareLink"];

            // Append the ID number as a query parameter
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
        final response = await http.post(
          Uri.parse("${apiUrl}V4/Others/Kurt/ArkLinkAPI/kurt_checkIdNumber.php"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"idNumber": idNumber}),
        );

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
        final response = await http.get(Uri.parse("${apiUrl}V4/Others/Kurt/ArkLinkAPI/kurt_fetchProfile.php?idNumber=$idNumber"));

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
        final response = await http.post(
          Uri.parse("${apiUrl}V4/Others/Kurt/ArkLinkAPI/kurt_updateLanguage.php"),
          body: {
            'idNumber': idNumber,
            'languageFlag': languageFlag.toString(),
          },
        );

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