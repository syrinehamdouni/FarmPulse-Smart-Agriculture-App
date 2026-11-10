import 'package:flutter/material.dart';
import 'image_helper.dart';
import 'user_manager.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late String _selectedLanguageCode;

  final List<Map<String, String>> _languages = [
    {'name': 'Français', 'code': 'fr', 'flag': '🇫🇷'},
    {'name': 'العربية', 'code': 'ar', 'flag': '🇹🇳'},
    {'name': 'English', 'code': 'en', 'flag': '🇺🇸'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedLanguageCode = UserManager().user.languageCode;
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
        title: Text(
          _getTitle(),
          style: const TextStyle(color: Color(0xFF1C5000), fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              _getSubtitle(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4C8C2B)),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _languages.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
              itemBuilder: (context, index) {
                final lang = _languages[index];
                final isSelected = _selectedLanguageCode == lang['code'];
                
                return ListTile(
                  onTap: () {
                    setState(() {
                      _selectedLanguageCode = lang['code']!;
                    });
                    UserManager().changeLanguage(lang['code']!);
                  },
                  leading: Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
                  title: Text(
                    lang['name']!,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF4C8C2B) : Colors.black,
                    ),
                  ),
                  trailing: isSelected 
                    ? const Icon(Icons.check_circle, color: Color(0xFF4C8C2B)) 
                    : null,
                );
              },
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'lang_fab',
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
  }

  String _getTitle() {
    switch (_selectedLanguageCode) {
      case 'ar': return 'اللغة';
      case 'en': return 'Language';
      default: return 'Langue';
    }
  }

  String _getSubtitle() {
    switch (_selectedLanguageCode) {
      case 'ar': return 'اختر لغتك';
      case 'en': return 'Choose your language';
      default: return 'Choisir votre langue';
    }
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
              _navItem(Icons.home_filled, _getNavLabel('home'), false, () => Navigator.pushReplacementNamed(context, '/home')),
              _navItem(Icons.location_on, 'GPS', false, () => Navigator.pushNamed(context, '/gps')),
              const SizedBox(width: 48),
              _navItem(Icons.calendar_month, _getNavLabel('agenda'), false, () => Navigator.pushNamed(context, '/agenda')),
              _navItem(Icons.eco, _getNavLabel('plant'), false, () => Navigator.pushNamed(context, '/crop_prediction')),
            ],
          ),
        ),
      ),
    );
  }

  String _getNavLabel(String type) {
    if (type == 'home') {
       if (_selectedLanguageCode == 'ar') return 'الرئيسية';
       if (_selectedLanguageCode == 'en') return 'Home';
       return 'Accueil';
    } else if (type == 'agenda') {
       if (_selectedLanguageCode == 'ar') return 'الأجندة';
       if (_selectedLanguageCode == 'en') return 'Agenda';
       return 'Agenda';
    } else {
       if (_selectedLanguageCode == 'ar') return 'الزراعة';
       if (_selectedLanguageCode == 'en') return 'Crop';
       return 'Culture';
    }
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
