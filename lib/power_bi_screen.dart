import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PowerBIScreen extends StatefulWidget {
  final String portalUrl;
  const PowerBIScreen({super.key, required this.portalUrl});

  @override
  State<PowerBIScreen> createState() => _PowerBIScreenState();
}

class _PowerBIScreenState extends State<PowerBIScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.portalUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de Bord Power BI', style: TextStyle(color: Color(0xFF1C5000), fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFBFBF1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1C5000)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.green),
            ),
        ],
      ),
    );
  }
}
