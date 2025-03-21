import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'auto_update.dart';

class SoftwareWebViewScreen extends StatefulWidget {
  final int linkID;

  SoftwareWebViewScreen({required this.linkID});

  @override
  _SoftwareWebViewScreenState createState() => _SoftwareWebViewScreenState();
}

class _SoftwareWebViewScreenState extends State<SoftwareWebViewScreen> {
  late final WebViewController _controller;
  final ApiService apiService = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _webUrl;
  final TextEditingController _idController = TextEditingController();
  String? _savedIdNumber;
  String? _profilePictureUrl;
  String? _firstName;
  String? _surName;
  bool _isLoading = true;
  int? _currentLanguageFlag; // Track the current language flag
  double _progress = 0; // Track the loading progress

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _progress = 0;
            });
          },
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _progress = 1;
            });
          },
        ),
      );

    _fetchAndLoadUrl();
    _loadIdNumber();
    _fetchProfile();
    _loadCurrentLanguageFlag();

    // Check for updates
    AutoUpdate.checkForUpdate(context);
  }

  Future<void> _loadIdNumber() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _savedIdNumber = prefs.getString('IDNumber');
    if (_savedIdNumber != null) {
      setState(() {
        _idController.text = _savedIdNumber!;
      });
    }
  }

  Future<void> _fetchProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? idNumber = prefs.getString('IDNumber');

    if (idNumber != null) {
      try {
        final profileData = await apiService.fetchProfile(idNumber);
        if (profileData["success"] == true) {
          setState(() {
            _firstName = profileData["firstName"];
            _surName = profileData["surName"];
            _profilePictureUrl = "${ApiService.apiUrls[1]}V4/11-A%20Employee%20List%20V2/profilepictures/${profileData["picture"]}";
            _currentLanguageFlag = profileData["languageFlag"];
          });
        }
      } catch (e) {
        print("Error fetching profile: $e");
      }
    }
  }

  Future<void> _saveIdNumber() async {
    String newIdNumber = _idController.text.trim();

    if (newIdNumber.isEmpty) {
      setState(() {
        _idController.text = _savedIdNumber ?? '';
      });

      Fluttertoast.showToast(
        msg: "ID Number cannot be empty!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    if (newIdNumber == _savedIdNumber) {
      Fluttertoast.showToast(
        msg: "Edit the ID number first!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    try {
      bool idExists = await apiService.checkIdNumber(newIdNumber);

      if (idExists) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('IDNumber', newIdNumber);
        _savedIdNumber = newIdNumber;

        Fluttertoast.showToast(
          msg: "ID Number saved successfully!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );

        _fetchAndLoadUrl();
        _fetchProfile(); // Refresh profile data
      } else {
        Fluttertoast.showToast(
          msg: "This ID Number does not exist in the employee database.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );

        setState(() {
          _idController.text = _savedIdNumber ?? '';
        });
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Failed to verify ID Number",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      setState(() {
        _idController.text = _savedIdNumber ?? '';
      });
    }
  }

  Future<void> _fetchAndLoadUrl() async {
    try {
      String url = await apiService.fetchSoftwareLink(widget.linkID);
      if (mounted) {
        setState(() {
          _webUrl = url;
        });
        _controller.loadRequest(Uri.parse(url));
      }
    } catch (e) {
      debugPrint("Error fetching link: $e");
    }
  }

  Future<void> _loadCurrentLanguageFlag() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentLanguageFlag = prefs.getInt('languageFlag');
    });
  }

  Future<void> _updateLanguageFlag(int flag) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? idNumber = prefs.getString('IDNumber');

    if (idNumber != null) {
      setState(() {
        _currentLanguageFlag = flag;
      });
      try {
        await apiService.updateLanguageFlag(idNumber, flag);
        await prefs.setInt('languageFlag', flag);

        String? currentUrl = await _controller.currentUrl();

        if (currentUrl != null) {
          _controller.loadRequest(Uri.parse(currentUrl));
        } else {
          _controller.reload();
        }
      } catch (e) {
        print("Error updating language flag: $e");
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false; // Prevent the app from popping the current screen
    } else {
      return true; // Allow the app to pop the current screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: false,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight - 20),
          child: AppBar(
            backgroundColor: Color(0xFF2053B3),
            centerTitle: true,
            toolbarHeight: kToolbarHeight - 20,
            leading: Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: IconButton(
                icon: Icon(
                  Icons.settings,
                  color: Colors.white,
                ),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: IconButton(
                  icon: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                    alignment: Alignment.center,
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: () {
                    SystemNavigator.pop();
                  },
                ),
              ),
            ],
          ),
        ),
        drawer: SizedBox(
          width: MediaQuery.of(context).size.width * 0.70,
          child: Drawer(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    color: Color(0xFF2053B3),
                    padding: EdgeInsets.only(top: 50, bottom: 20),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            backgroundImage: _profilePictureUrl != null
                                ? NetworkImage(_profilePictureUrl!)
                                : null,
                            child: _profilePictureUrl == null
                                ? FlutterLogo(size: 60)
                                : null,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          _firstName != null && _surName != null
                              ? "$_firstName $_surName"
                              : "User Name",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Text(
                          "Language",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 25),
                        GestureDetector(
                          onTap: () => _updateLanguageFlag(1),
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/images/americanFlag.gif',
                                width: 40,
                                height: 40,
                              ),
                              if (_currentLanguageFlag == 1)
                                Container(
                                  height: 2,
                                  width: 40,
                                  color: Colors.blue,
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: 25),
                        GestureDetector(
                          onTap: () => _updateLanguageFlag(2),
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/images/japaneseFlag.gif',
                                width: 40,
                                height: 40,
                              ),
                              if (_currentLanguageFlag == 2)
                                Container(
                                  height: 2,
                                  width: 40,
                                  color: Colors.blue,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "User",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        TextField(
                          controller: _idController,
                          decoration: InputDecoration(
                            hintText: "ID Number",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveIdNumber,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF2053B3),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              "Save",
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            if (_webUrl != null)
              WebViewWidget(controller: _controller),
            if (_isLoading)
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
          ],
        ),
      ),
    );
  }
}