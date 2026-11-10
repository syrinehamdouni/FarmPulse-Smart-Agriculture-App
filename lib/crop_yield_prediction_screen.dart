import 'package:flutter/material.dart';
import 'image_helper.dart';
import 'services/crop_service.dart';

class CropYieldPredictionScreen extends StatefulWidget {
  const CropYieldPredictionScreen({super.key});

  @override
  State<CropYieldPredictionScreen> createState() => _CropYieldPredictionScreenState();
}

class _CropYieldPredictionScreenState extends State<CropYieldPredictionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showResult = false;
  bool _isDetailsExpanded = false;

  bool _isLoading = false;
  CropPredictionResult? predictionResult;

  final List<String> _crops = ["Wheat", "Maize", "Olives", "Orange"];
  final List<String> _locations = ["Tunis", "Sfax", "Sousse", "Béja", "Jendouba", "Kairouan"];
  final List<String> _inputNeedsList = ["Irrigation", "Fertilizer", "Pesticides", "None"];
  final List<String> _climatesList = ["Arid", "Semi-Arid", "Mediterranean", "Humide"];
  final List<String> _soilTypesList = ["Loamy", "Clay", "Sandy", "Chalky"];
  final List<String> _risksList = ["Low", "Medium", "High"];

  final TextEditingController _farmSizeController = TextEditingController(text: "60");
  final TextEditingController _cropTypeController = TextEditingController(text: "Wheat");
  final TextEditingController _soilPHController = TextEditingController(text: "6.5");
  final TextEditingController _moistureController = TextEditingController(text: "40");
  final TextEditingController _nitrogenController = TextEditingController(text: "30");
  final TextEditingController _phosphorusController = TextEditingController(text: "15");
  final TextEditingController _potassiumController = TextEditingController(text: "20");
  final TextEditingController _precipitationController = TextEditingController(text: "700");
  final TextEditingController _tempAmplitudeController = TextEditingController(text: "15");
  final TextEditingController _locationController = TextEditingController(text: "Tunis");
  final TextEditingController _inputNeedsController = TextEditingController(text: "Irrigation");
  final TextEditingController _climateConditionController = TextEditingController(text: "Semi-Arid");
  final TextEditingController _soilTypeController = TextEditingController(text: "Loamy");
  final TextEditingController _droughtRiskController = TextEditingController(text: "Low");

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    _farmSizeController.dispose();
    _cropTypeController.dispose();
    _soilPHController.dispose();
    _moistureController.dispose();
    _nitrogenController.dispose();
    _phosphorusController.dispose();
    _potassiumController.dispose();
    _precipitationController.dispose();
    _tempAmplitudeController.dispose();
    _locationController.dispose();
    _inputNeedsController.dispose();
    _climateConditionController.dispose();
    _soilTypeController.dispose();
    _droughtRiskController.dispose();
    super.dispose();
  }

  Future<void> _predict() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await CropService.predictYield(
        farmSize: double.tryParse(_farmSizeController.text) ?? 0.0,
        cropType: _cropTypeController.text.trim(),
        soilPH: double.tryParse(_soilPHController.text) ?? 0.0,
        moisture: double.tryParse(_moistureController.text) ?? 0.0,
        nitrogen: double.tryParse(_nitrogenController.text) ?? 0.0,
        phosphorus: double.tryParse(_phosphorusController.text) ?? 0.0,
        potassium: double.tryParse(_potassiumController.text) ?? 0.0,
        precipitation: double.tryParse(_precipitationController.text) ?? 0.0,
        tempAmplitude: double.tryParse(_tempAmplitudeController.text) ?? 0.0,
        inputNeeds: _inputNeedsController.text,
        location: _locationController.text,
        climateCondition: _climateConditionController.text,
        soilType: _soilTypeController.text,
        droughtRisk: _droughtRiskController.text,
      );

      setState(() {
        predictionResult = result;
        _showResult = true;
      });

      _controller.forward(from: 0.0);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildDropdownField(TextEditingController controller, String label, IconData icon, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: items.contains(controller.text) ? controller.text : items.first,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.green.shade700),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              controller.text = newValue;
            });
          }
        },
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.green.shade700),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  void _showEditBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const Padding(padding: EdgeInsets.all(20.0), child: Text('Modifier les informations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1C5000)))),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildInputField(_farmSizeController, 'Taille (ha)', Icons.landscape),
                    _buildDropdownField(_cropTypeController, 'Culture', Icons.eco, _crops),
                    _buildDropdownField(_locationController, 'Emplacement', Icons.location_on, _locations),
                    _buildInputField(_soilPHController, 'pH du sol', Icons.science),
                    _buildInputField(_moistureController, 'Humidité (%)', Icons.water_drop),
                    _buildInputField(_nitrogenController, 'Azote (N)', Icons.science_outlined),
                    _buildInputField(_phosphorusController, 'Phosphore (P)', Icons.science_outlined),
                    _buildInputField(_potassiumController, 'Potassium (K)', Icons.science_outlined),
                    _buildInputField(_precipitationController, 'Précipitation (mm)', Icons.cloudy_snowing),
                    _buildInputField(_tempAmplitudeController, 'Amplitude thermique', Icons.thermostat),
                    _buildDropdownField(_inputNeedsController, 'Besoins en intrants', Icons.shopping_basket, _inputNeedsList),
                    _buildDropdownField(_climateConditionController, 'Condition climatique', Icons.wb_sunny, _climatesList),
                    _buildDropdownField(_soilTypeController, 'Type de sol', Icons.layers, _soilTypesList),
                    _buildDropdownField(_droughtRiskController, 'Risque de sécheresse', Icons.warning_amber, _risksList),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); _predict(); },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C5000), minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text('Actualiser la prédiction', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            if (!_showResult) _buildInputForm(),
            if (_showResult) _buildResults(),
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'crop_prediction_fab',
        onPressed: () => ImageHelper.showImageSourceDialog(context),
        backgroundColor: const Color(0xFF171717),
        shape: const CircleBorder(),
        child: Container(margin: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFF00DF00), shape: BoxShape.circle), child: const Center(child: Icon(Icons.camera_alt, color: Colors.black, size: 24))),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Container(height: 250, width: double.infinity, decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/bg6.png'), fit: BoxFit.cover))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(backgroundColor: Colors.white.withOpacity(0.9), child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context))),
                    const Text('Prédiction de rendement 🍃', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Obtenez une estimation de votre rendement', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF1C5000), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Données Ferme & Sol', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
              const SizedBox(height: 16),
              _buildInputField(_farmSizeController, 'Taille (ha)', Icons.landscape),
              _buildDropdownField(_cropTypeController, 'Culture', Icons.eco, _crops),
              _buildDropdownField(_locationController, 'Emplacement', Icons.location_on, _locations),
              _buildInputField(_soilPHController, 'pH du sol', Icons.science),
              _buildInputField(_moistureController, 'Humidité (%)', Icons.water_drop),
              _buildInputField(_nitrogenController, 'Azote (N)', Icons.science_outlined),
              _buildInputField(_phosphorusController, 'Phosphore (P)', Icons.science_outlined),
              _buildInputField(_potassiumController, 'Potassium (K)', Icons.science_outlined),
              _buildInputField(_precipitationController, 'Précipitation (mm)', Icons.cloudy_snowing),
              _buildInputField(_tempAmplitudeController, 'Amplitude thermique', Icons.thermostat),
              _buildDropdownField(_inputNeedsController, 'Besoins en intrants', Icons.shopping_basket, _inputNeedsList),
              _buildDropdownField(_climateConditionController, 'Condition climatique', Icons.wb_sunny, _climatesList),
              _buildDropdownField(_soilTypeController, 'Type de sol', Icons.layers, _soilTypesList),
              _buildDropdownField(_droughtRiskController, 'Risque de sécheresse', Icons.warning_amber, _risksList),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _predict,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C5000), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Calculer la prédiction',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    return FadeTransition(
      opacity: _animation,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInputSummaryCard(),
            const SizedBox(height: 16),
            _buildScoreOverview(),
            const SizedBox(height: 16),
            _buildYieldCard(),
            const SizedBox(height: 16),
            _buildRecommendations(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _showEditBottomSheet(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C5000), minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Modifier les paramètres', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _scoreItem('Soil Health', predictionResult?.soilScore ?? 0, Colors.brown),
          _scoreItem('Productivity', predictionResult?.productivityScore ?? 0, Colors.green),
          _scoreItem('Confidence', (predictionResult?.predictedYield != null) ? 85 : 0, Colors.blue),
        ],
      ),
    );
  }

  Widget _scoreItem(String label, int score, Color color) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 60,
              width: 60,
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 6,
                backgroundColor: color.withOpacity(0.1),
                color: color,
              ),
            ),
            Text('$score%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildInputSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text('Résumé des entrées', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
              const Spacer(),
              IconButton(
                onPressed: () => _showEditBottomSheet(context),
                icon: const Icon(Icons.edit, color: Colors.green, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _summaryRow(Icons.landscape, 'Taille', '${_farmSizeController.text} ha'),
                    _summaryRow(Icons.eco_outlined, 'Culture', _cropTypeController.text),
                    _summaryRow(Icons.location_on_outlined, 'Emplacement', _locationController.text),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _summaryRow(Icons.science_outlined, 'pH Sol', _soilPHController.text),
                    _summaryRow(Icons.water_drop_outlined, 'Humidité', '${_moistureController.text}%'),
                    _summaryRow(Icons.category, 'Cluster', 'AI #${predictionResult?.cluster ?? "?"}'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.green.shade700),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recommandations AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
          const SizedBox(height: 16),
          if (predictionResult?.anomaly ?? false)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 12),
                  Expanded(child: Text('Anomalie détectée dans les données!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          ...(predictionResult?.recommendations ?? []).map(
            (rec) => _recommendationItem(Icons.tips_and_updates_outlined, rec),
          ),
        ],
      ),
    );
  }

  Widget _recommendationItem(IconData icon, String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Icon(icon, size: 20, color: Colors.green), const SizedBox(width: 12), Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87)))]));
  }

  Widget _buildYieldCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [const Icon(Icons.eco, color: Colors.green), const SizedBox(width: 8), const Text('Rendement prédit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  predictionResult?.predictedYield.toStringAsFixed(2) ?? "0.00",
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C5000),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(predictionResult?.unit.toUpperCase() ?? 'TONNES', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const Text('PAR HECTARE', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const Divider(),
            InkWell(
              onTap: () => setState(() => _isDetailsExpanded = !_isDetailsExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_isDetailsExpanded ? "Moins de détails" : "Plus de détails", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    Icon(_isDetailsExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.green),
                  ],
                ),
              ),
            ),
            if (_isDetailsExpanded) ...[
              const SizedBox(height: 10),
              _buildDetailRow("Azote (N)", _nitrogenController.text),
              _buildDetailRow("Phosphore (P)", _phosphorusController.text),
              _buildDetailRow("Potassium (K)", _potassiumController.text),
              _buildDetailRow("Précipitation", "${_precipitationController.text} mm"),
              _buildDetailRow("Température", "${_tempAmplitudeController.text}°C"),
              _buildDetailRow("Type de sol", _soilTypeController.text),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1C5000))),
        ],
      ),
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
              _navItem(Icons.home_filled, 'Home', false, () => Navigator.pushReplacementNamed(context, '/home')),
              _navItem(Icons.location_on, 'GPS', false, () => Navigator.pushNamed(context, '/gps')),
              const SizedBox(width: 48),
              _navItem(Icons.calendar_month, 'Agenda', false, () => Navigator.pushNamed(context, '/agenda')),
              _navItem(Icons.eco, 'Culture', true, () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: active ? const Color(0xFF00DF00) : Colors.white, size: 24), Text(label, style: TextStyle(fontSize: 10, color: active ? const Color(0xFF00DF00) : Colors.white))]),
    );
  }
}
