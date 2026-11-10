import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'user_manager.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  Future<void> _handleSignup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // Create user in Firebase Auth
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Save additional user data in Firestore
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        // جلب البيانات فوراً لضمان تحديث واجهة المستخدم
        await UserManager().fetchUserData();

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } on FirebaseAuthException catch (e) {
        String message = "Une erreur est survenue";
        if (e.code == 'weak-password') {
          message = "Le mot de passe est trop faible";
        } else if (e.code == 'email-already-in-use') {
          message = "Ce compte existe déjà pour cet e-mail";
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      
      // Sync Firestore data for Google users
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();
      if (!userDoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'fullName': userCredential.user!.displayName ?? '',
          'email': userCredential.user!.email ?? '',
          'phone': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await UserManager().fetchUserData();

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur Google Sign-In: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg.png', 
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 450),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text('Créer un compte', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
                            const Text('Rejoignez FarmPulse !', style: TextStyle(fontSize: 16, color: Colors.grey)),
                            const SizedBox(height: 25),
                            
                            _buildTextFormField(
                              controller: _nameController,
                              hint: 'Nom complet',
                              icon: Icons.person_outline,
                              validator: (value) => (value == null || value.isEmpty) ? "Veuillez remplir ce champ" : null,
                            ),
                            const SizedBox(height: 16),
                            
                            _buildTextFormField(
                              controller: _emailController,
                              hint: 'Adresse e-mail',
                              icon: Icons.email_outlined,
                              validator: (value) {
                                if (value == null || value.isEmpty) return "Veuillez remplir ce champ";
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return "Veuillez saisir une adresse e-mail valide";
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            _buildTextFormField(
                              controller: _passwordController,
                              hint: 'Mot de passe',
                              icon: Icons.lock_outline,
                              isPassword: true,
                              obscureText: _obscurePassword,
                              onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                              validator: (value) {
                                if (value == null || value.isEmpty) return "Veuillez remplir ce champ";
                                if (value.length < 6) return "Le mot de passe doit contenir au moins 6 caractères";
                                return null;
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            _buildTextFormField(
                              controller: _confirmPasswordController,
                              hint: 'Confirmer le mot de passe',
                              icon: Icons.lock_outline,
                              isPassword: true,
                              obscureText: _obscureConfirmPassword,
                              onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              validator: (value) {
                                if (value == null || value.isEmpty) return "Veuillez remplir ce champ";
                                if (value != _passwordController.text) return "Les mots de passe ne correspondent pas";
                                return null;
                              },
                            ),
                            
                            const SizedBox(height: 30),
                            _buildSignupButton(),
                            const SizedBox(height: 20),
                            const Text('OU', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 20),
                            _buildGoogleButton(),
                            const SizedBox(height: 25),
                            Column(
                              children: [
                                const Text('Vous avez déjà un compte ?'),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: const Text("Se connecter", style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF1C5000), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? obscureText : false,
      textAlign: TextAlign.left,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.green.shade700),
        suffixIcon: isPassword ? IconButton(icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: onToggle) : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }

  Widget _buildSignupButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleSignup,
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF7CB342), Color(0xFF1C5000)]),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: _isLoading 
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("S'INSCRIRE", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton(
      onPressed: _isLoading ? null : _handleGoogleSignIn,
      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/img.png', height: 22, errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata)),
          const SizedBox(width: 12),
          const Text('Continuer avec Google', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
