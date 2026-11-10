import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'plant_diagnostic_screen.dart';
import 'user_manager.dart';

class ImageHelper {
  static final ImagePicker _picker = ImagePicker();

  static void showImageSourceDialog(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    final UserManager userManager = UserManager();
    
    String getLang() => userManager.user.languageCode;
    String tr(String fr, String ar, String en) {
      if (getLang() == 'ar') return ar;
      if (getLang() == 'en') return en;
      return fr;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              tr('Analyser votre plante', 'تحليل نبتتك', 'Analyze your plant'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C5000),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('Choisissez une source pour prendre la photo', 'اختر مصدراً لالتقاط الصورة', 'Choose a source to take the photo'),
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(
                  modalContext,
                  icon: Icons.camera_alt_rounded,
                  label: tr('Appareil photo', 'الكاميرا', 'Camera'),
                  color: const Color(0xFF4C8C2B),
                  onTap: () async {
                    Navigator.pop(modalContext);
                    try {
                      final XFile? pickedFile = await _picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 80,
                      );
                      if (pickedFile != null) {
                        navigator.push(
                          MaterialPageRoute(
                            builder: (context) => PlantDiagnosticScreen(imagePath: pickedFile.path),
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint('Error: $e');
                    }
                  },
                ),
                _buildSourceOption(
                  modalContext,
                  icon: Icons.photo_library_rounded,
                  label: tr('Galerie', 'المعرض', 'Gallery'),
                  color: const Color(0xFF1C5000),
                  onTap: () async {
                    Navigator.pop(modalContext);
                    try {
                      final XFile? pickedFile = await _picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                      );
                      if (pickedFile != null) {
                        navigator.push(
                          MaterialPageRoute(
                            builder: (context) => PlantDiagnosticScreen(imagePath: pickedFile.path),
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint('Error: $e');
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static Widget _buildSourceOption(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.2), width: 1),
            ),
            child: Icon(icon, color: color, size: 35),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
