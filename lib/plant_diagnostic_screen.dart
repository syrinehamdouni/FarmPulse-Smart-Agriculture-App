import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_manager.dart';
import 'image_helper.dart';
import '../services/plant_diagnostic_service.dart';

class PlantDiagnosticScreen extends StatefulWidget {
  final String imagePath;
  const PlantDiagnosticScreen({super.key, required this.imagePath});

  @override
  State<PlantDiagnosticScreen> createState() => _PlantDiagnosticScreenState();
}

class _PlantDiagnosticScreenState extends State<PlantDiagnosticScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isAnalyzing = true;
  PlantDiagnosticResult? diagnosticResult;
  bool _loadingError = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _analyzeImage();
  }

  Future<void> _analyzeImage() async {
    try {
      final result = await PlantDiagnosticService.diagnosePlant(
        imagePath: widget.imagePath,
        region: "Tunisia",
      );

      if (mounted) {
        setState(() {
          diagnosticResult = result;
          _isAnalyzing = false;
        });

        _controller.stop();

        _saveDiagnosticToFirebase();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingError = true;
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveDiagnosticToFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('diagnostics')
            .add({
          'disease': diagnosticResult?.disease,
          'confidence': diagnosticResult?.confidence,
          'date': FieldValue.serverTimestamp(),
          'imagePath': widget.imagePath,
        });
      }
    } catch (e) {
      debugPrint("Erreur lors de l'enregistrement Firebase: $e");
    }
  }

  Future<void> _saveAsPdf() async {
    final pdf = pw.Document();
    final imageBytes = File(widget.imagePath).readAsBytesSync();
    final image = pw.MemoryImage(imageBytes);
    final userName = UserManager().user.name;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('FarmPulse - Rapport', style: pw.TextStyle(color: PdfColors.green, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date: ${DateTime.now().toString().substring(0, 10)}'),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Text('Agriculteur: $userName'),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text('Rapport de Diagnostic de Plante',
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Container(
                    height: 250,
                    child: pw.Image(image),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Maladie détectée: ${diagnosticResult?.disease ?? ""}',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                pw.SizedBox(height: 10),
                pw.Text('Confiance: ${diagnosticResult?.confidence ?? 0}%', style: pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 20),
                pw.Header(level: 1, text: 'À propos de cette maladie'),
                pw.Text(
                    'La tache bactérienne est causée par Xanthomonas campestris pv. vesicatoria. Elle provoque des taches brunes sur les feuilles, les fruits et les tiges.'),
                pw.SizedBox(height: 20),
                pw.Header(level: 1, text: 'Recommandations'),
                pw.Bullet(text: 'Évitez l\'irrigation par aspersion.'),
                pw.Bullet(text: 'Éliminez les feuilles et fruits infectés.'),
                pw.Bullet(text: 'Utilisez des variétés résistantes si possible.'),
                pw.Bullet(text: 'Appliquez un traitement à base de cuivre.'),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'diagnostic_plante_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
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
          'Diagnostic des plantes 🍃',
          style: TextStyle(
            color: Color(0xFF1C5000),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildImageCard(),
            if (!_isAnalyzing) ...[
              const SizedBox(height: 16),
              _buildResultCard(),
              const SizedBox(height: 16),
              _buildHeatMapCard(),
              const SizedBox(height: 16),
              _buildRecommendationsCard(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_outlined, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Image sélectionnée',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1C5000)),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(
                  File(widget.imagePath),
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              if (_isAnalyzing)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Positioned(
                      top: _controller.value * 180,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                          gradient: const LinearGradient(
                            colors: [Colors.transparent, Colors.green, Colors.transparent],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              if (_isAnalyzing)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text(
                            'Analyse en cours...',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text('Résultat du diagnostic', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.coronavirus_outlined, color: Colors.red, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Maladie détectée', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(
                      diagnosticResult?.disease ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C5000),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Confiance', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const Spacer(),
                        Text(
                          '${diagnosticResult?.confidence.toStringAsFixed(2) ?? 0}%',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (diagnosticResult?.confidence ?? 0) / 100,
                      backgroundColor: Colors.grey[200],
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          const Text('À propos de cette maladie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          const Text(
            'La tache bactérienne est causée par Xanthomonas campestris pv. vesiicatoria. Elle provoque des taches brunes sur les feuilles, les fruits et les tiges.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatMapCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_outlined, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text('Carte de chaleur (Zones affectées)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: diagnosticResult?.heatmapBase64 != null
                ? Image.memory(
                    base64Decode(
                      diagnosticResult!.heatmapBase64!,
                    ),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    File(widget.imagePath),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tips_and_updates_outlined, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text('Recommandations', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          ...(diagnosticResult?.treatment ?? [])
              .map((e) => _recommendationItem(e))
              .toList(),
          ...(diagnosticResult?.prevention ?? [])
              .map((e) => _recommendationItem(e))
              .toList(),
        ],
      ),
    );
  }

  Widget _recommendationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            ImageHelper.showImageSourceDialog(context);
          },
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Diagnostiquer une autre image'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            foregroundColor: const Color(0xFF1C5000),
            side: const BorderSide(color: Colors.grey, width: 0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _saveAsPdf,
          icon: const Icon(Icons.save_outlined, color: Colors.white),
          label: const Text('Enregistrer le résultat', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF388E3C),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
