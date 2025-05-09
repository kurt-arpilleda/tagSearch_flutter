import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart'; // For image viewing

class PDFViewerScreen extends StatefulWidget {
  final String fileUrl;
  final String fileName;
  final int languageFlag;

  const PDFViewerScreen({
    Key? key,
    required this.fileUrl,
    required this.fileName,
    required this.languageFlag,
  }) : super(key: key);

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  String? localPath;
  bool isLoading = true;
  bool isError = false;
  String errorMessage = '';
  double downloadProgress = 0.0;
  DateTime? remoteLastModified;
  bool _isImageFile = false;

  @override
  void initState() {
    super.initState();
    _isImageFile = _checkIfImage(widget.fileUrl);
    loadFile();
  }

  bool _checkIfImage(String url) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
    final lowerUrl = url.toLowerCase();
    return imageExtensions.any((ext) => lowerUrl.endsWith(ext));
  }

  Future<void> loadFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${widget.fileName}');

      // First, check the remote file's last modified date
      final headResponse = await http.head(Uri.parse(widget.fileUrl));
      if (headResponse.statusCode != 200) {
        throw Exception('Failed to check file: ${headResponse.statusCode}');
      }

      final lastModifiedHeader = headResponse.headers['last-modified'];
      remoteLastModified = lastModifiedHeader != null
          ? HttpDate.parse(lastModifiedHeader)
          : null;

      // Check if file exists and compare modification dates
      bool shouldDownload = true;
      if (await file.exists()) {
        final localLastModified = await file.lastModified();
        shouldDownload = remoteLastModified != null &&
            localLastModified.isBefore(remoteLastModified!);
      }

      if (shouldDownload) {
        final request = await http.Client().send(http.Request('GET', Uri.parse(widget.fileUrl)));

        if (request.statusCode != 200) {
          throw Exception('Failed to download file: ${request.statusCode}');
        }

        final contentLength = request.contentLength ?? 0;
        final List<int> bytes = [];
        int received = 0;

        await for (var chunk in request.stream) {
          bytes.addAll(chunk);
          received += chunk.length;

          if (contentLength != 0) {
            setState(() {
              downloadProgress = received / contentLength;
            });
          }
        }

        await file.writeAsBytes(bytes);

        if (remoteLastModified != null) {
          await file.setLastModified(remoteLastModified!);
        }
      }

      setState(() {
        localPath = file.path;
        isLoading = false;
      });

    } catch (e) {
      setState(() {
        isError = true;
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2053B3),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.languageFlag == 2 ? '手引き' : 'Manual',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              overflow: TextOverflow.ellipsis,
              fontWeight: FontWeight.bold
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? buildLoading()
          : isError
          ? Center(child: Text('Error: $errorMessage'))
          : _isImageFile
          ? PhotoView(
        imageProvider: FileImage(File(localPath!)),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2,
      )
          : PDFView(
        filePath: localPath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: false,
        pageSnap: false,
        onError: (error) {
          debugPrint(error.toString());
        },
        onPageError: (page, error) {
          debugPrint('$page: ${error.toString()}');
        },
      ),
    );
  }

  Widget buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (downloadProgress > 0) ...[
              Text(
                remoteLastModified != null ? 'Updating document...' : 'Downloading...',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2053B3),
                ),
              ),
              const SizedBox(height: 24),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: downloadProgress,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2053B3)),
                    ),
                  ),
                  Text(
                    '${(downloadProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2053B3)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Preparing document...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}