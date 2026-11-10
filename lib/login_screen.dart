import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // 1. Log in via Auth only (very fast)
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        
        // 2. Navigate immediately to the main screen
        // UserManager will fetch data in the background without blocking the user
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } on FirebaseAuthException catch (e) {
        String message = "Une erreur est survenue";
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          message = "L'adresse e-mail ou le mot de passe est incorrect";
        } else if (e.code == 'invalid-email') {
          message = "Format d'e-mail incorrect";
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
      
      // Sync Firestore for new users only
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();
      if (!userDoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'fullName': userCredential.user!.displayName ?? '',
          'email': userCredential.user!.email ?? '',
          'phone': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Immediate transition
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
              'assets/bg_l.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) => Container(color: Colors.green.shade100),
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
                            const Text('Bienvenue !', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
                            const Text('Connectez-vous pour continuer', style: TextStyle(fontSize: 14, color: Colors.grey)),
                            const SizedBox(height: 25),
                            
                            _buildTextFormField(
                              controller: _emailController,
                              hint: 'Adresse e-mail',
                              icon: Icons.email_outlined,
                              validator: (value) {
                                if (value == null || value.isEmpty) return "Veuillez saisir votre adresse e-mail";
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return "Format d'e-mail incorrect";
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
                                if (value == null || value.isEmpty) return "Veuillez saisir votre mot de passe";
                                if (value.length < 6) return "Le mot de passe doit contenir au moins 6 caractères";
                                return null;
                              },
                            ),
                            
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.pushNamed(context, '/forgot_password'),
                                child: const Text('Mot de passe oublié ?', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildLoginButton(),
                            const SizedBox(height: 20),
                            const Text('OU', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 20),
                            _buildGoogleButton(),
                            const SizedBox(height: 25),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Pas encore de compte ? '),
                                GestureDetector(
                                  onTap: () => Navigator.pushNamed(context, '/signup'),
                                  child: const Text("S'inscrire", style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 16)),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleLogin,
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF7CB342), Color(0xFF1C5000)]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: _isLoading 
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('SE CONNECTER', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton(
      onPressed: _isLoading ? null : _handleGoogleSignIn,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        side: BorderSide(color: Colors.grey.shade300),
      ),
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
