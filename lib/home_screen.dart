import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'image_helper.dart';
import 'user_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _temp = "--°C";
  String _condition = "Chargement...";
  String _humidity = "--%";
  String _windSpeed = "-- km/h";
  String _city = "Localisation...";
  bool _isLoadingWeather = true;
  final UserManager _userManager = UserManager();
  late final WebViewController _powerBIController;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
    _initPowerBI();
  }

  void _initPowerBI() {
    _powerBIController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..loadRequest(Uri.parse('https://app.powerbi.com/reportEmbed?reportId=73d5db8f-cb23-4968-a061-97dcc3594fe4&autoAuth=true&embeddedDemo=true'));
  }

  Future<void> _fetchWeather() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _city = "Permission refusée";
            _isLoadingWeather = false;
          });
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 10));

      const apiKey = "ed5e3505b30fea63c2b2fcc21270d79b";
      final url = "https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=metric&lang=fr";

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _temp = "${data['main']['temp'].toInt()}°C";
          _condition = data['weather'][0]['description'].toString().toUpperCase();
          _humidity = "${data['main']['humidity']}%";
          _windSpeed = "${(data['wind']['speed'] * 3.6).toInt()} km/h";
          _city = data['name'];
          _isLoadingWeather = false;
        });
      } else {
        setState(() {
          _city = "Erreur API";
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      setState(() { 
        _city = "Erreur connexion";
        _isLoadingWeather = false; 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _userManager,
      builder: (context, child) {
        final user = _userManager.user;
        return Scaffold(
          backgroundColor: const Color(0xFFFBFBF1),
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, user),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGreeting(user),
                        const SizedBox(height: 16),
                        _buildMainBanner(),
                        const SizedBox(height: 24),
                        const Text('Power BI Analysis', 
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1C5000), fontSize: 18)),
                        const SizedBox(height: 12),
                        _buildPowerBIDashboard(),
                        const SizedBox(height: 24),
                        _buildAgendaSection(context),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'home_fab',
            onPressed: () => ImageHelper.showImageSourceDialog(context),
            backgroundColor: const Color(0xFF171717),
            shape: const CircleBorder(),
            elevation: 8,
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF00DF00),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.camera_alt, color: Colors.black, size: 24),
              ),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: _buildBottomNavBar(context),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, UserProfile user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: CircleAvatar(
              radius: 24, 
              backgroundColor: Colors.grey.shade200,
              backgroundImage: user.imagePath != null
                  ? (user.imagePath!.startsWith('http') || kIsWeb 
                      ? NetworkImage(user.imagePath!) 
                      : FileImage(File(user.imagePath!)) as ImageProvider)
                  : const AssetImage('assets/profile.png'),
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('FARM PULSE', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1C5000), fontSize: 18)),
                  SizedBox(width: 4),
                  Icon(Icons.eco, color: Colors.green, size: 18),
                ],
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/chatbot'),
            child: Image.asset('assets/chatboot.png', width: 50, height: 50),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting(UserProfile user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bonjour, ${user.name.split(' ')[0]} ! 👋', 
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
          Text('Location: $_city', style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMainBanner() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        image: const DecorationImage(image: AssetImage('assets/home.png'), fit: BoxFit.cover),
      ),
      child: Stack(
        children: [
          Positioned(left: 0, bottom: 0, child: Image.asset('assets/f.png', height: 180)),
          Positioned(
            right: 16, top: 20, bottom: 20,
            child: Container(
              width: 150, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(24)),
              child: _isLoadingWeather 
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wb_sunny, color: Colors.orange, size: 32),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_temp, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            Text(_condition, style: const TextStyle(fontSize: 8, color: Colors.grey), textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    ],
                  ),
                  const Divider(height: 24),
                  _weatherInfoRow(Icons.opacity, 'Humidité', _humidity),
                  const SizedBox(height: 6),
                  _weatherInfoRow(Icons.air, 'Vent', _windSpeed),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weatherInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.green, size: 14),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPowerBIDashboard() {
    return Container(
      height: 500,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: WebViewWidget(controller: _powerBIController),
      ),
    );
  }

  Widget _buildAgendaSection(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/agenda'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: Color(0xFF1C5000)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Agenda de culture', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
                  const Text('Planifiez vos semis et récoltes', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BottomAppBar(
          height: 80,
          color: const Color(0xFF171717),
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_filled, 'Home', true, () => Navigator.pushReplacementNamed(context, '/home')),
              _navItem(Icons.location_on, 'GPS', false, () => Navigator.pushNamed(context, '/gps')),
              const SizedBox(width: 48), 
              _navItem(Icons.calendar_month, 'Agenda', false, () => Navigator.pushNamed(context, '/agenda')),
              _navItem(Icons.eco, 'Plant', false, () => Navigator.pushNamed(context, '/crop_prediction')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? const Color(0xFF00DF00) : Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: active ? const Color(0xFF00DF00) : Colors.white,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
