import 'package:flutter/material.dart';
import 'webview.dart';
import 'id_input_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? idNumber = prefs.getString('IDNumber');
  runApp(MyApp(initialRoute: idNumber == null ? '/idInput' : '/webView'));
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  MyApp({required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tag Search',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: initialRoute,
      routes: {
        '/idInput': (context) => IdInputDialog(),
        '/webView': (context) => SoftwareWebViewScreen(linkID: 1),
      },
    );
  }
}
