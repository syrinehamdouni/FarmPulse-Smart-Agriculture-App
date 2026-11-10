import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/agenda_service.dart';

class PlantSelectionScreen extends StatefulWidget {
  final DateTime selectedDate;
  const PlantSelectionScreen({super.key, required this.selectedDate});

  @override
  State<PlantSelectionScreen> createState() => _PlantSelectionScreenState();
}

class _PlantSelectionScreenState extends State<PlantSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? selectedPlant;
  Map<String, dynamic>? customPlant;
  bool _isLoading = false;

  final List<Map<String, dynamic>> plants = [
    {
      'name': 'Tomate',
      'image': 'assets/tomate.png',
      'water': '2-3 litres/jour',
      'frequency': 'Chaque matin',
      'cycle': 60,
    },
    {
      'name': 'Pomme de terre',
      'image': 'assets/potato.png',
      'water': '1.5 litres/jour',
      'frequency': 'Tous les 2 jours',
      'cycle': 90,
    },
    {
      'name': 'Poivron',
      'image': 'assets/pepper.png',
      'water': '1 litre/jour',
      'frequency': 'Deux fois par semaine',
      'cycle': 70,
    },
    {
      'name': 'Olive',
      'image': 'assets/olive.png',
      'water': '4-5 litres (irrigation ciblée)',
      'frequency': 'Une fois par semaine',
      'cycle': 180,
    },
    {
      'name': 'Laitue',
      'image': 'assets/lettuce.png',
      'water': '1 litre/jour',
      'frequency': 'Tous les matins',
      'cycle': 45,
    },
  ];

  List<Map<String, dynamic>> filteredPlants = [];

  @override
  void initState() {
    super.initState();
    filteredPlants = plants;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      filteredPlants = plants
          .where((p) => p['name'].toLowerCase().contains(query))
          .toList();
      
      if (query.isNotEmpty && filteredPlants.isEmpty) {
        customPlant = {
          'name': _searchController.text,
          'image': 'assets/tomate.png',
          'water': '2.0 litres/jour (Standard)',
          'frequency': 'Quotidien',
          'cycle': 45,
        };
        selectedPlant = customPlant!['name'];
      } else if (query.isEmpty) {
        customPlant = null;
        selectedPlant = null;
      } else {
        customPlant = null;
      }
    });
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
        title: const Text('Sélectionner une plante', style: TextStyle(color: Color(0xFF1C5000), fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plantation le : ${widget.selectedDate.day}/${widget.selectedDate.month}/${widget.selectedDate.year}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tapez le nom de la plante...',
                    prefixIcon: const Icon(Icons.edit, color: Colors.green),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty 
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                      : null,
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Suggestions :', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      if (customPlant != null)
                        _buildPlantCard(customPlant!, true),
                      ...filteredPlants.map((plant) {
                        final isSelected = selectedPlant == plant['name'];
                        return _buildPlantCard(plant, isSelected);
                      }).toList(),
                      if (filteredPlants.isEmpty && customPlant == null)
                        const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(child: Text("Commencez à taper pour ajouter une plante", style: TextStyle(color: Colors.grey))),
                        ),
                    ],
                  ),
                ),
                if (selectedPlant != null) _buildPlantDetails(),
                const SizedBox(height: 20),
                if (selectedPlant != null)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () async {
                        setState(() { _isLoading = true; });
                        try {
                          Map<String, dynamic> plant;
                          if (customPlant != null && selectedPlant == customPlant!['name']) {
                            plant = customPlant!;
                          } else {
                            plant = plants.firstWhere((p) => p['name'] == selectedPlant);
                          }

                          final result = await AgendaService.getAgenda(
                            plantType: plant['name'],
                            plantingDate: DateFormat('yyyy-MM-dd').format(widget.selectedDate),
                            city: "Tunis",
                          );

                          if (mounted) {
                            Navigator.pop(context, {
                              'date': widget.selectedDate,
                              'plant': {
                                ...plant,
                                'ai_data': result,
                              },
                            });
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        } finally {
                          if (mounted) setState(() { _isLoading = false; });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C5000),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Confirmer la plantation', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.1),
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF1C5000))),
            ),
        ],
      ),
    );
  }

  Widget _buildPlantCard(Map<String, dynamic> plant, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPlant = plant['name'];
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.transparent,
            width: 2,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Image.asset(plant['image'], width: 50, height: 50),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plant['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Cycle : ${plant['cycle']} jours', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantDetails() {
    Map<String, dynamic> plant;
    if (customPlant != null && selectedPlant == customPlant!['name']) {
      plant = customPlant!;
    } else {
      plant = plants.firstWhere((p) => p['name'] == selectedPlant, orElse: () => customPlant!);
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Besoins pour ${plant['name']} :', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.opacity, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              Text('Eau : ${plant['water']}', style: const TextStyle(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text('Fréquence : ${plant['frequency']}', style: const TextStyle(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}
