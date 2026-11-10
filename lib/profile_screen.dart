import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'user_manager.dart';
import 'image_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final userManager = UserManager();

  Future<void> _handleLogout() async {
    await auth.FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: userManager,
      builder: (context, child) {
        final user = userManager.user;
        
        return Scaffold(
          backgroundColor: const Color(0xFFFBFBF1), 
          body: Stack(
            children: [
              Positioned(
                bottom: -10,
                left: -10,
                child: Image.asset('assets/left.png', width: 150, errorBuilder: (context, error, stackTrace) => const SizedBox()),
              ),
              Positioned(
                bottom: -10,
                right: -10,
                child: Image.asset('assets/right.png', width: 150, errorBuilder: (context, error, stackTrace) => const SizedBox()),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      _buildCustomAppBar(context),
                      const SizedBox(height: 20),
                      _buildProfileHeader(user),
                      const SizedBox(height: 20),
                      _buildMenuCard(context, user),
                      const SizedBox(height: 30),
                      _buildLogoutButton(context),
                      const SizedBox(height: 15),
                      const Text('Version 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 120), 
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'profile_fab',
            onPressed: () => ImageHelper.showImageSourceDialog(context),
            backgroundColor: const Color(0xFF171717),
            shape: const CircleBorder(),
            elevation: 8,
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Color(0xFF00DF00), shape: BoxShape.circle),
              child: const Center(child: Icon(Icons.camera_alt, color: Colors.black, size: 24)),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: _buildBottomNavBar(context),
        );
      },
    );
  }

  Widget _buildCustomAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFF1C5000), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            ),
          ),
          const Row(
            children: [
              Text('Mon Profil', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
              SizedBox(width: 8),
              Icon(Icons.eco, color: Color(0xFF4C8C2B), size: 24),
            ],
          ),
          const SizedBox(width: 45), 
        ],
      ),
    );
  }

  Widget _buildProfileHeader(UserProfile user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  child: Image.asset('assets/bg.png', height: 160, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  bottom: -50,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.grey.shade100,
                          backgroundImage: user.imagePath != null
                              ? (user.imagePath!.startsWith('http') || kIsWeb 
                                  ? NetworkImage(user.imagePath!) 
                                  : FileImage(File(user.imagePath!)) as ImageProvider)
                              : const AssetImage('assets/profile.png'),
                        ),
                      ),
                      Positioned(
                        bottom: 5, right: 5,
                        child: GestureDetector(
                          onTap: () => ImageHelper.showImageSourceDialog(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, size: 18, color: Color(0xFF4C8C2B)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),
            Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
            Text(user.email, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, UserProfile user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            _buildMenuItem(Icons.person_outline, 'Informations personnelles', '${user.name}, ${user.phone.isEmpty ? "Pas de téléphone" : user.phone}', onTap: () => Navigator.pushNamed(context, '/edit_info')),
            _divider(),
            _buildMenuItem(Icons.agriculture_outlined, 'Ma ferme', 'Informations sur votre ferme', onTap: () => Navigator.pushNamed(context, '/my_farm')),
            _divider(),
            _buildMenuItem(Icons.notifications_none, 'Notifications', 'Gérer vos préférences', onTap: () => Navigator.pushNamed(context, '/notifications')),
            _divider(),
            _buildMenuItem(Icons.language, 'Langue', 'Français', onTap: () => Navigator.pushNamed(context, '/language')),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Icon(icon, color: const Color(0xFF4C8C2B), size: 26),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
    );
  }

  Widget _divider() => Divider(height: 1, color: Colors.grey.shade100, indent: 60);

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ElevatedButton(
        onPressed: _handleLogout,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFF5F5),
          foregroundColor: Colors.red,
          elevation: 0,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.red.withOpacity(0.1))),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('SE DÉCONNECTER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(width: 10),
            Icon(Icons.logout_rounded),
          ],
        ),
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: active ? const Color(0xFF00DF00) : Colors.white, size: 24), const SizedBox(height: 4), Text(label, style: TextStyle(fontSize: 10, color: active ? const Color(0xFF00DF00) : Colors.white))]),
    );
  }
}
