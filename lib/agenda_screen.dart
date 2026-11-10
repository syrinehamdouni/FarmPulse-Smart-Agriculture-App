import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'image_helper.dart';
import 'plant_selection_screen.dart';
import 'package:intl/intl.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  
  final Map<DateTime, Map<String, dynamic>> _plantAssignments = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  DateTime _normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<void> _loadAssignments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('agenda')
          .get();

      setState(() {
        _plantAssignments.clear();
        for (var doc in snapshot.docs) {
          final date = DateTime.parse(doc.id);
          _plantAssignments[_normalize(date)] = doc.data();
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur lors du chargement de l'agenda: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAssignment(DateTime date, Map<String, dynamic> plant) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dateKey = _formatDateKey(date);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('agenda')
          .doc(dateKey)
          .set(plant);
      
      setState(() {
        _plantAssignments[_normalize(date)] = plant;
      });
    } catch (e) {
      debugPrint("Erreur lors de la sauvegarde: $e");
    }
  }

  Future<void> _deleteAssignment(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dateKey = _formatDateKey(date);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('agenda')
          .doc(dateKey)
          .delete();
      
      setState(() {
        _plantAssignments.remove(_normalize(date));
      });
    } catch (e) {
      debugPrint("Erreur lors de la suppression: $e");
    }
  }

  void _previousMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
    });
  }

  Map<String, dynamic>? _getHarvestInfo(DateTime date) {
    final targetDate = _normalize(date);
    for (var entry in _plantAssignments.entries) {
      final plantDate = entry.key;
      final aiData = entry.value['ai_data'];
      if (aiData != null && aiData['harvest_date'] != null) {
        // Optionnel: On peut calculer la date de récolte si elle n'est pas stockée comme objet DateTime
        // Mais pour simplifier on regarde si c'est le jour de récolte via ai_data
      }
      // Logique existante simplifiée
      final cycle = entry.value['cycle'] as int;
      final harvestDate = plantDate.add(Duration(days: cycle));
      if (_normalize(harvestDate) == targetDate) {
        return entry.value;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final normalizedSelected = _normalize(_selectedDay);
    bool hasPlant = _plantAssignments.containsKey(normalizedSelected);
    Map<String, dynamic>? harvestInfo = _getHarvestInfo(_selectedDay);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF1),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1C5000)))
        : SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMonthSelector(),
                      const SizedBox(height: 12),
                      _buildCalendarGrid(),
                      const SizedBox(height: 24),
                      if (harvestInfo != null)
                        _buildHarvestState(harvestInfo)
                      else if (hasPlant)
                        _buildPlantDetailState(_plantAssignments[normalizedSelected]!)
                      else
                        _buildAddPlantState(),
                      const SizedBox(height: 24),
                      _buildDailyRecommendations(),
                      const SizedBox(height: 24),
                      _buildHarvestTracking(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
      bottomNavigationBar: _buildBottomNavBar(context),
      floatingActionButton: FloatingActionButton(
        heroTag: 'agenda_fab',
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
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Container(
          height: 160,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg7.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Column(
                  children: [
                    Text(
                      'Agenda Intelligent',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1C5000)),
                    ),
                    Text('Gérez vos cultures au quotidien', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.calendar_month, color: Colors.black),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSelector() {
    String monthName = DateFormat.MMMM('fr_FR').format(_focusedDay);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "${monthName[0].toUpperCase()}${monthName.substring(1)} ${_focusedDay.year}",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1C5000)),
        ),
        Row(
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: _previousMonth),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1).weekday;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: daysInMonth + (firstDayOfMonth - 1),
      itemBuilder: (context, index) {
        if (index < firstDayOfMonth - 1) return const SizedBox();
        final day = index - (firstDayOfMonth - 2);
        final date = DateTime(_focusedDay.year, _focusedDay.month, day);
        final normalizedDate = _normalize(date);
        
        bool isSelected = normalizedDate == _normalize(_selectedDay);
        bool hasPlant = _plantAssignments.containsKey(normalizedDate);
        bool isHarvest = _getHarvestInfo(date) != null;

        return GestureDetector(
          onTap: () => setState(() => _selectedDay = date),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1C5000) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: hasPlant || isHarvest ? Colors.green : Colors.transparent,
                  width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  day.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (hasPlant && !isSelected)
                  Positioned(
                    bottom: 2,
                    child: Image.asset(_plantAssignments[normalizedDate]!['image'], width: 14, height: 14),
                  ),
                if (isHarvest && !isSelected)
                  const Positioned(
                    top: 2,
                    right: 2,
                    child: Icon(Icons.auto_awesome, size: 12, color: Colors.orange),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddPlantState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.eco_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Rien de prévu pour ce jour', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PlantSelectionScreen(selectedDate: _selectedDay)),
              );
              if (result != null) {
                _saveAssignment(result['date'], result['plant']);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C5000),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ajouter une culture', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantDetailState(Map<String, dynamic> plant) {
    final aiData = plant['ai_data'];
    
    String harvestDateStr = aiData != null ? aiData['harvest_date'] : "À définir";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (aiData != null) ...[
          _buildWeatherCard(aiData),
          const SizedBox(height: 16),
        ],
        const Text('Agenda de culture', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Image.asset(plant['image'], width: 60, height: 60),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plant['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Phase: ${aiData != null ? aiData['stage'] : "Croissance"}', style: const TextStyle(color: Colors.green, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteAssignment(_selectedDay),
                  )
                ],
              ),
              const Divider(height: 32),
              _buildActionItem(
                Icons.water_drop, 
                'Arrosage Intelligent', 
                'Quantité: ${aiData != null ? aiData['irrigation']['qty'] : plant['water']}'
              ),
              const SizedBox(height: 12),
              _buildActionItem(
                Icons.timer, 
                'Fréquence', 
                'Planifié: ${aiData != null ? aiData['irrigation']['freq'] : plant['frequency']}'
              ),
              const SizedBox(height: 12),
              _buildActionItem(Icons.local_florist, 'Phase actuelle', aiData != null ? aiData['stage'] : 'Croissance'),
              const SizedBox(height: 12),
              _buildActionItem(Icons.event_available, 'Date de récolte estimée', harvestDateStr),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherCard(Map<String, dynamic> aiData) {
    final weather = aiData['weather'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _weatherItem(Icons.thermostat, "${weather['temperature']}°C"),
          _weatherItem(Icons.water_drop, "${weather['humidity']}%"),
          _weatherItem(Icons.cloud, "${weather['rain']} mm"),
        ],
      ),
    );
  }

  Widget _weatherItem(IconData icon, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.green),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHarvestState(Map<String, dynamic> plant) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        children: [
          const Icon(Icons.shopping_basket, size: 48, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'C\'est le jour de la récolte !',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 8),
          Text(
            'Vos ${plant['name']} sont prêts à être récoltés.',
            style: const TextStyle(color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String title, String desc) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.blue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyRecommendations() {
    final normalizedSelected = _normalize(_selectedDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recommandations quotidiennes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _plantAssignments.containsKey(normalizedSelected) 
                    ? 'Le temps est ensoleillé aujourd\'hui. Idéal pour vos ${_plantAssignments[normalizedSelected]!['name']}.'
                    : 'Planifiez vos prochaines cultures pour optimiser votre récolte.',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHarvestTracking() {
    String nextHarvestDateStr = "Aucune récolte prévue";
    DateTime? soonestHarvest;
    
    for (var entry in _plantAssignments.entries) {
      final aiData = entry.value['ai_data'];
      int cycle = entry.value['cycle'] as int;
      if (aiData != null && aiData['remaining_days'] != null) {
        // Optionnel: On pourrait utiliser remaining_days ici
      }
      final harvestDate = entry.key.add(Duration(days: cycle));
      if (soonestHarvest == null || harvestDate.isBefore(soonestHarvest)) {
        if (harvestDate.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
           soonestHarvest = harvestDate;
        }
      }
    }

    if (soonestHarvest != null) {
      nextHarvestDateStr = DateFormat('dd MMMM yyyy', 'fr_FR').format(soonestHarvest);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Suivi de récolte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Prochaine récolte estimée:', style: TextStyle(fontSize: 13)),
                  Text(nextHarvestDateStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
              const SizedBox(height: 8),
              const LinearProgressIndicator(value: 0.6, backgroundColor: Color(0xFFEEEEEE), color: Colors.green),
            ],
          ),
        ),
      ],
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
              _navItem(Icons.home_filled, 'Accueil', false, () => Navigator.pushReplacementNamed(context, '/home')),
              _navItem(Icons.location_on, 'GPS', false, () => Navigator.pushNamed(context, '/gps')),
              const SizedBox(width: 48),
              _navItem(Icons.calendar_month, 'Agenda', true, () {}),
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
