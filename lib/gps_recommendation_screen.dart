import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'image_helper.dart';
import 'user_manager.dart';
import 'services/gps_ai_service.dart';

class GpsRecommendationScreen extends StatefulWidget {
  const GpsRecommendationScreen({super.key});

  @override
  State<GpsRecommendationScreen> createState() => _GpsRecommendationScreenState();
}

class _GpsRecommendationScreenState extends State<GpsRecommendationScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  bool _isAnalyzing = false;
  bool _showResults = false;
  final UserManager _userManager = UserManager();

  String _getLang() => _userManager.user.languageCode;

  String _tr(String fr, String ar, String en) {
    if (_getLang() == 'ar') return ar;
    if (_getLang() == 'en') return en;
    return fr;
  }

  Map<String, dynamic>? _aiResult;

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      _mapController.move(currentLatLng, 15);
      setState(() {
        _selectedLocation = currentLatLng;
        _showResults = false;
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _onTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
      _showResults = false;
    });
  }

  void _handleAnalyze() async {
    if (_selectedLocation == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final result = await GpsAiService.predictCrop(
        lat: _selectedLocation!.latitude,
        lng: _selectedLocation!.longitude,
      );

      setState(() {
        _aiResult = result;
        _showResults = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr("Erreur de connexion avec l'IA", "خطأ في الاتصال بالذكاء الاصطناعي", "AI Connection Error")),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      body: Stack(
        children: [
          _buildMap(),
          if (_showResults && _aiResult != null) _buildForegroundContent(),
          _buildTopOverlay(),
          if (!_showResults) _buildInitialPrompt(),
          _buildMyLocationButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'gps_fab',
        onPressed: () => ImageHelper.showImageSourceDialog(context),
        backgroundColor: const Color(0xFF171717),
        shape: const CircleBorder(),
        child: Container(margin: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFF00DF00), shape: BoxShape.circle), child: const Center(child: Icon(Icons.camera_alt, color: Colors.black, size: 24))),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildMyLocationButton() {
    return Positioned(
      right: 16,
      bottom: _showResults ? MediaQuery.of(context).size.height * 0.45 + 16 : 100,
      child: FloatingActionButton(
        mini: true,
        onPressed: _getCurrentLocation,
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Color(0xFF1C5000)),
      ),
    );
  }

  Widget _buildInitialPrompt() {
    return Positioned(
      bottom: 20, left: 20, right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_selectedLocation == null ? Icons.touch_app : Icons.check_circle, color: const Color(0xFF1C5000), size: 32),
                const SizedBox(height: 8),
                Text(
                  _selectedLocation == null 
                      ? _tr('Veuillez cliquer sur l\'emplacement de votre terrain sur la carte', 'يرجى النقر على موقع أرضك على الخريطة', 'Please click on the location of your land on the map')
                      : _tr('Terrain sélectionné ! Cliquez sur "Envoyer pour analyse"', 'تم اختيار الأرض! اضغط على "إرسال للتحليل"', 'Land selected! Click "Send for analysis"'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isAnalyzing ? null : _handleAnalyze,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C5000), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _isAnalyzing 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(_tr('Envoyer pour analyse (IA)', 'إرسال للتحليل (IA)', 'Send for analysis (AI)'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return SizedBox(
      height: _showResults ? MediaQuery.of(context).size.height * 0.45 : MediaQuery.of(context).size.height,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: const LatLng(36.8065, 10.1815), initialZoom: 13, onTap: _onTap),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.bi_ai'),
          if (_selectedLocation != null) MarkerLayer(markers: [Marker(point: _selectedLocation!, width: 80, height: 80, child: const Icon(Icons.location_on, color: Colors.green, size: 40))]),
        ],
      ),
    );
  }

  Widget _buildTopOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _circleButton(Icons.arrow_back, () => Navigator.pop(context)),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_tr('GPS & Recommandation Smart 🍃', 'نظام GPS والتوصيات الذكية 🍃', 'GPS & Smart Recommendation 🍃'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                Text(_tr('Aperçus propulsés par l\'IA', 'رؤى مدعومة بالذكاء الاصطناعي', 'AI-powered insights'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onPressed) => Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle), child: IconButton(icon: Icon(icon, color: Colors.black87, size: 20), onPressed: onPressed));

  Widget _buildForegroundContent() {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(color: Color(0xFFF4F7F2), borderRadius: BorderRadius.vertical(top: Radius.circular(32)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 5)]),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLocationCard(),
                const SizedBox(height: 16),
                _buildAiPredictionCard(),
                const SizedBox(height: 16),
                _buildConditionSummary(),
                const SizedBox(height: 16),
                _buildRecommendationsList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Color(0xFF1C5000), size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tr('Emplacement du champ', 'موقع الحقل', 'Field location'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${_selectedLocation?.latitude.toStringAsFixed(4)}° N, ${_selectedLocation?.longitude.toStringAsFixed(4)}° E', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiPredictionCard() {
    // Robust fallbacks for AI Result
    final double confidence = (_aiResult?['confidence'] ?? 0.0).toDouble();
    final String cropName = _aiResult?['recommended_crop']?.toString() ?? _tr('N/A', 'غير متوفر', 'N/A');
    final String yieldVal = _aiResult?['expected_yield']?['max']?.toString() ?? '0.0';
    final String reason = _aiResult?['recommendation_reason']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(_tr('Résultats de prédiction IA', 'نتائج توقعات الذكاء الاصطناعي', 'AI prediction results'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                child: Text('${_tr("Confiance", "الثقة", "Confidence")}: ${(confidence * 100).toInt()}%', style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle), child: const Icon(Icons.agriculture, color: Colors.orange, size: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cropName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
                    Text(_tr('Meilleur choix pour votre sol', 'الخيار الأفضل لتربتك', 'Best choice for your soil'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(yieldVal, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                  Text(_tr('tonnes/ha', 'طن/هكتار', 'tons/ha'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              )
            ],
          ),
          if (reason.isNotEmpty) ...[
            const Divider(height: 32),
            Text(reason, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Widget _buildConditionSummary() {
    final String risk = _aiResult?['risk_level']?.toString() ?? _tr('Normal', 'عادي', 'Normal');
    final List alternatives = (_aiResult?['alternative_crops'] as List?) ?? [];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_tr('Résumé des conditions', 'ملخص الظروف', 'Conditions summary'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem(_tr('Risque', 'المخاطر', 'Risk'), risk, Icons.warning_amber, Colors.orange),
              _summaryItem(_tr('Alt 1', 'بديل 1', 'Alt 1'), alternatives.isNotEmpty ? alternatives[0].toString() : '-', Icons.eco_outlined, Colors.green),
              _summaryItem(_tr('Alt 2', 'بديل 2', 'Alt 2'), alternatives.length >= 2 ? alternatives[1].toString() : '-', Icons.eco_outlined, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon, Color color) {
    return Column(children: [Icon(icon, color: color, size: 22), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]);
  }

  Widget _buildRecommendationsList() {
    final List recommendations = (_aiResult?['recommendations'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), child: Text(_tr('Recommandations IA', 'توصيات الذكاء الاصطناعي', 'AI Recommendations'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        if (recommendations.isEmpty)
           Container(
             width: double.infinity,
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
             child: Text(_tr('Aucune recommandation spécifique', 'لا توجد توصيات محددة', 'No specific recommendations'), style: const TextStyle(color: Colors.grey)),
           ),
        ...recommendations.map((rec) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [const Icon(Icons.check_circle_outline, color: Colors.green, size: 20), const SizedBox(width: 12), Expanded(child: Text(rec.toString(), style: const TextStyle(fontSize: 13)))]),
        )),
      ],
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BottomAppBar(
          height: 80, color: const Color(0xFF171717),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_filled, _tr('Home', 'الرئيسية', 'Home'), false, () => Navigator.pushReplacementNamed(context, '/home')),
              _navItem(Icons.location_on, 'GPS', true, () {}),
              const SizedBox(width: 48), 
              _navItem(Icons.calendar_month, _tr('Agenda', 'الأجندة', 'Agenda'), false, () => Navigator.pushNamed(context, '/agenda')),
              _navItem(Icons.eco, _tr('Plant', 'زراعة', 'Plant'), false, () => Navigator.pushNamed(context, '/crop_prediction')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: active ? const Color(0xFF00DF00) : Colors.white, size: 24), const SizedBox(height: 4), Text(label, style: TextStyle(fontSize: 10, color: active ? const Color(0xFF00DF00) : Colors.white))]),
    );
  }
}
