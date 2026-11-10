import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'image_helper.dart';
import 'user_manager.dart';

class MyFarmScreen extends StatefulWidget {
  const MyFarmScreen({super.key});

  @override
  State<MyFarmScreen> createState() => _MyFarmScreenState();
}

class _MyFarmScreenState extends State<MyFarmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _farmNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _surfaceController = TextEditingController();
  
  final _yieldController = TextEditingController();
  final _irrigationController = TextEditingController();
  final _soilController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  final UserManager _userManager = UserManager();

  @override
  void initState() {
    super.initState();
    _loadFarmData();
  }

  Future<void> _loadFarmData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _farmNameController.text = data['farmName'] ?? '';
          _locationController.text = data['farmLocation'] ?? '';
          _surfaceController.text = data['farmSurface'] ?? '';
          _yieldController.text = data['cropYield'] ?? '';
          _irrigationController.text = data['irrigation'] ?? '';
          _soilController.text = data['soil'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Erreur: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFarmData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    try {
      await _userManager.updateFirestoreUser(
        cropYield: _yieldController.text.trim(),
        irrigation: _irrigationController.text.trim(),
        soil: _soilController.text.trim(),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'farmName': _farmNameController.text.trim(),
          'farmLocation': _locationController.text.trim(),
          'farmSurface': _surfaceController.text.trim(),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informations de la ferme enregistrées avec succès')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _farmNameController.dispose();
    _locationController.dispose();
    _surfaceController.dispose();
    _yieldController.dispose();
    _irrigationController.dispose();
    _soilController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1C5000)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ma ferme',
          style: TextStyle(color: Color(0xFF1C5000), fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1C5000)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Détails de votre ferme',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4C8C2B)),
              ),
              const SizedBox(height: 20),
              _buildLabel('Nom de la ferme'),
              _buildTextField(_farmNameController, Icons.agriculture, 'Ex: Ma Ferme Bio'),
              const SizedBox(height: 20),
              _buildLabel('Emplacement'),
              _buildTextField(_locationController, Icons.location_on_outlined, 'Ex: Ariana tunisia'),
              const SizedBox(height: 20),
              _buildLabel('Surface (Hectares)'),
              _buildTextField(_surfaceController, Icons.square_foot, 'Ex: 5'),
              
              const SizedBox(height: 30),
              const Text(
                'Statistiques en temps réel',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4C8C2B)),
              ),
              const SizedBox(height: 20),
              _buildLabel('Rendement (Ex: +18%)'),
              _buildTextField(_yieldController, Icons.trending_up, 'Entrez le rendement'),
              const SizedBox(height: 20),
              _buildLabel('Irrigation (Ex: 82%)'),
              _buildTextField(_irrigationController, Icons.water_drop, 'Entrez le niveau d\'irrigation'),
              const SizedBox(height: 20),
              _buildLabel('État du Sol (Ex: Bon)'),
              _buildTextField(_soilController, Icons.landscape, 'Entrez l\'état du sol'),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveFarmData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4C8C2B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'ENREGISTRER TOUT',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'my_farm_fab',
        onPressed: () => ImageHelper.showImageSourceDialog(context),
        backgroundColor: const Color(0xFF171717),
        shape: const CircleBorder(),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: const BoxDecoration(color: Color(0xFF00DF00), shape: BoxShape.circle),
          child: const Center(child: Icon(Icons.camera_alt, color: Colors.black, size: 24)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildTextField(TextEditingController controller, IconData icon, String hint) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF4C8C2B)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
      validator: (value) => (value == null || value.isEmpty) ? 'Ce champ est requis' : null,
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BottomAppBar(
          height: 80,
          color: const Color(0xFF171717),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_filled, 'Home', false, () => Navigator.pushReplacementNamed(context, '/home')),
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
          Text(label, style: TextStyle(fontSize: 10, color: active ? const Color(0xFF00DF00) : Colors.white)),
        ],
      ),
    );
  }
}
