import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'image_helper.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _smsNotifications = true;
  bool _orderUpdates = true;
  bool _promotions = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _pushNotifications = data['push'] ?? true;
          _emailNotifications = data['email'] ?? false;
          _smsNotifications = data['sms'] ?? true;
          _orderUpdates = data['orders'] ?? true;
          _promotions = data['promotions'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("Erreur lors du chargement des paramètres: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .set({key: value}, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Erreur lors de la mise à jour: $e");
    }
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
          'Notifications',
          style: TextStyle(color: Color(0xFF1C5000), fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1C5000)))
        : ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          const Text(
            'Préférences de notification',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4C8C2B)),
          ),
          const SizedBox(height: 20),
          _buildSwitchTile(
            'Notifications Push',
            'Recevoir des alertes sur votre appareil',
            _pushNotifications,
            (val) {
              setState(() => _pushNotifications = val);
              _updateSetting('push', val);
            },
          ),
          _buildSwitchTile(
            'Notifications par e-mail',
            'Recevoir des mises à jour par e-mail',
            _emailNotifications,
            (val) {
              setState(() => _emailNotifications = val);
              _updateSetting('email', val);
            },
          ),
          _buildSwitchTile(
            'Notifications SMS',
            'Recevoir des alertes par SMS',
            _smsNotifications,
            (val) {
              setState(() => _smsNotifications = val);
              _updateSetting('sms', val);
            },
          ),
          const Divider(height: 40),
          const Text(
            'Types de notifications',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          _buildSwitchTile(
            'Mises à jour des commandes',
            'Alertes sur l\'état de vos commandes',
            _orderUpdates,
            (val) {
              setState(() => _orderUpdates = val);
              _updateSetting('orders', val);
            },
          ),
          _buildSwitchTile(
            'Promotions et offres',
            'Recevoir des offres spéciales',
            _promotions,
            (val) {
              setState(() => _promotions = val);
              _updateSetting('promotions', val);
            },
          ),
          const SizedBox(height: 100),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'notifications_fab',
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

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      activeColor: const Color(0xFF4C8C2B),
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
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
