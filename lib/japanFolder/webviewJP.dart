import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'api_serviceJP.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../auto_update.dart';
import 'package:http/http.dart' as http;

class SoftwareWebViewScreenJP extends StatefulWidget {
  final int linkID;

  SoftwareWebViewScreenJP({required this.linkID});

  @override
  _SoftwareWebViewScreenState createState() => _SoftwareWebViewScreenState();
}

class _SoftwareWebViewScreenState extends State<SoftwareWebViewScreenJP> {
  late final WebViewController _controller;
  final ApiServiceJP apiService = ApiServiceJP();
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
  String? _phOrJp; // Track the current country (ph or jp)
  bool _loadFailed = false; // Track if the load failed

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
              _loadFailed = false;
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
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _loadFailed = true;
            });
          },
        ),
      );

    _fetchAllData(); // Fetch all data on initialization
  }
  bool _isReloading = false;
  Future<void> _fetchAllData() async {
    setState(() {
      _isReloading = true; // Start loading
    });

    await _fetchAndLoadUrl(); // Fetch the web URL
    await _loadIdNumber(); // Load the saved ID number
    await _fetchProfile(); // Fetch the user profile
    await _loadCurrentLanguageFlag(); // Load the current language flag
    await _loadPhOrJp(); // Load the current country (ph or jp)

    setState(() {
      _isReloading = false; // Stop loading
    });
  }
  Future<void> _loadPhOrJp() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _phOrJp = prefs.getString('phorjp');
    });
  }

  Future<void> _loadIdNumber() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _savedIdNumber = prefs.getString('IDNumberJP');
    if (_savedIdNumber != null) {
      setState(() {
        _idController.text = _savedIdNumber!;
      });
    }
  }

  Future<void> _fetchProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? idNumber = prefs.getString('IDNumberJP');

    if (idNumber != null) {
      try {
        final profileData = await apiService.fetchProfile(idNumber);
        if (profileData["success"] == true) {
          String profilePictureFileName = profileData["picture"];

          String primaryUrl = "${ApiServiceJP.apiUrls[0]}V4/11-A%20Employee%20List%20V2/profilepictures/$profilePictureFileName";
          bool isPrimaryUrlValid = await _isImageAvailable(primaryUrl);

          String fallbackUrl = "${ApiServiceJP.apiUrls[1]}V4/11-A%20Employee%20List%20V2/profilepictures/$profilePictureFileName";
          bool isFallbackUrlValid = await _isImageAvailable(fallbackUrl);

          setState(() {
            _firstName = profileData["firstName"];
            _surName = profileData["surName"];
            _profilePictureUrl = isPrimaryUrlValid ? primaryUrl : isFallbackUrlValid ? fallbackUrl : null;
            _currentLanguageFlag = profileData["languageFlag"];
          });
        }
      } catch (e) {
        print("Error fetching profile: $e");
      }
    }
  }

  Future<bool> _isImageAvailable(String url) async {
    try {
      final response = await http.head(Uri.parse(url)).timeout(Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveIdNumber() async {
    String newIdNumber = _idController.text.trim();

    if (newIdNumber.isEmpty) {
      setState(() {
        _idController.text = _savedIdNumber ?? '';
      });

      Fluttertoast.showToast(
        msg: "ID番号を空にすることはできません！",
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
        msg: "まずID番号を編集してください！",
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
        await prefs.setString('IDNumberJP', newIdNumber);
        _savedIdNumber = newIdNumber;

        Fluttertoast.showToast(
          msg: "ID Number saved successfully!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );

        _fetchAllData(); // Refetch all data after saving the ID number
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
        msg: "ID番号の確認に失敗しました",
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
          _loadFailed = false;
        });
        _controller.loadRequest(Uri.parse(url));
      }
    } catch (e) {
      debugPrint("Error fetching link: $e");
      setState(() {
        _loadFailed = true;
      });
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
    String? idNumber = prefs.getString('IDNumberJP');

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

  Future<void> _updatePhOrJp(String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('phorjp', value);
    setState(() {
      _phOrJp = value;
    });

    String? idNumber = prefs.getString('IDNumber');
    String? idNumberJP = prefs.getString('IDNumberJP');

    if (value == "ph") {
      if (idNumber == null) {
        Navigator.pushReplacementNamed(context, '/idInput');
      } else {
        Navigator.pushReplacementNamed(context, '/webView');
      }
    } else if (value == "jp") {
      if (idNumberJP == null) {
        Navigator.pushReplacementNamed(context, '/idInputJP');
      } else {
        Navigator.pushReplacementNamed(context, '/webViewJP');
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
                  color: Colors.orangeAccent,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
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
                                    : "ユーザー名",
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
                                "言語",
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
                                "ユーザー",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5),
                              TextField(
                                controller: _idController,
                                decoration: InputDecoration(
                                  hintText: "ID番号",
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
                                    "保存",
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
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Text(
                        "国",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 25),
                      GestureDetector(
                        onTap: () => _updatePhOrJp("ph"),
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/philippines.png',
                              width: 40,
                              height: 40,
                            ),
                            if (_phOrJp == "ph")
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
                        onTap: () => _updatePhOrJp("jp"),
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/japan.png',
                              width: 40,
                              height: 40,
                            ),
                            if (_phOrJp == "jp")
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
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            if (_webUrl != null && !_loadFailed)
              WebViewWidget(controller: _controller),
            if (_isLoading)
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            if (_loadFailed)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _isReloading
                        ? CircularProgressIndicator(color: Colors.blue) // Show loading spinner
                        : IconButton(
                      icon: Icon(Icons.refresh, size: 50, color: Colors.blue),
                      onPressed: _fetchAllData, // Refetch all data on reload
                    ),
                    SizedBox(height: 10),
                    Text(
                      _isReloading ? "再読み込み中…" : "読み込みに失敗しました。タップして再試行してください。",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}