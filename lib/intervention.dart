import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// Petite fonction utilitaire pour formater une heure au format 2 chiffres (ex: 09:05)
String _formatHeure(TimeOfDay heure) {
  final h = heure.hour.toString().padLeft(2, '0');
  final m = heure.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Page d'intervention mécanique, formulaire de saisie et génération de PDF (sans signature)
class InterventionPage extends StatefulWidget {
  @override
  _InterventionPageState createState() => _InterventionPageState();
}

class _InterventionPageState extends State<InterventionPage> {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs de texte pour récupérer les saisies utilisateur
  final TextEditingController _entrepriseController = TextEditingController();
  final TextEditingController _typePanneController = TextEditingController();

  // Variables de date et heure, initialisées à la date/heure actuelles
  DateTime _dateJour = DateTime.now();
  TimeOfDay? _heureArrivee;
  TimeOfDay? _heureFin;

  bool _isLoading = false; // Affichage du loader lors de la génération PDF

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Intervention mécanique',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 4,
      ),
      // Le formulaire est scrollable pour s'adapter à tous les écrans
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionEntreprise(), // Bloc nom entreprise
              SizedBox(height: 20),
              _buildSectionDatesHeures(), // Bloc date et heures
              SizedBox(height: 20),
              _buildSectionTypePanne(), // Bloc description de la panne
              SizedBox(height: 32),
              _buildBoutonEnvoi(), // Bouton pour générer et partager le PDF
            ],
          ),
        ),
      ),
    );
  }

  /// Bloc UI : informations sur l'entreprise
  Widget _buildSectionEntreprise() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations Entreprise',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _entrepriseController,
              decoration: InputDecoration(
                labelText: 'Nom de l\'entreprise *',
                hintText: 'Saisissez le nom de l\'entreprise',
                prefixIcon: Icon(Icons.business, color: Colors.blue[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir le nom de l\'entreprise';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Bloc UI : sélection de la date et des heures d'intervention
  Widget _buildSectionDatesHeures() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dates et Heures',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            SizedBox(height: 16),

            // Date du jour (remplie automatiquement)
            ListTile(
              leading: Icon(Icons.today, color: Colors.green[600]),
              title: Text('Date du jour'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_dateJour)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            SizedBox(height: 12),

            // Sélection des heures d'arrivée et de fin
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    leading: Icon(Icons.access_time, color: Colors.orange[600]),
                    title: Text('Heure d\'arrivée'),
                    subtitle: Text(_heureArrivee != null
                        ? _heureArrivee!.format(context)
                        : 'Sélectionner'),
                    onTap: () => _selectionnerHeure(true),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ListTile(
                    leading:
                        Icon(Icons.access_time_filled, color: Colors.red[600]),
                    title: Text('Heure de fin'),
                    subtitle: Text(_heureFin != null
                        ? _heureFin!.format(context)
                        : 'Sélectionner'),
                    onTap: () => _selectionnerHeure(false),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Bloc UI : description de la panne
  Widget _buildSectionTypePanne() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type de Panne',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _typePanneController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description de la panne *',
                hintText: 'Décrivez le type de panne rencontré...',
                prefixIcon: Icon(Icons.build, color: Colors.blue[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez décrire le type de panne';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Unique bouton d'envoi pour générer le PDF et le partager
  Widget _buildBoutonEnvoi() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _genererEtPartagerPDF,
        icon: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(Icons.send, color: Colors.white),
        label: Text(
          _isLoading ? 'Envoi en cours...' : 'Générer PDF et Partager',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[600],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  /// Sélection de l'heure via le sélecteur natif Flutter
  Future<void> _selectionnerHeure(bool isArrivee) async {
    final TimeOfDay? heure = await showTimePicker(
      context: context,
      initialTime: isArrivee
          ? (_heureArrivee ?? TimeOfDay.now())
          : (_heureFin ?? TimeOfDay.now()),
    );

    if (heure != null) {
      setState(() {
        if (isArrivee) {
          _heureArrivee = heure;
        } else {
          _heureFin = heure;
        }
      });
    }
  }

  /// Génère le PDF, sauvegarde en temporaire, puis lance le partage natif
  Future<void> _genererEtPartagerPDF() async {
    if (!_formKey.currentState!.validate()) {
      _afficherMessage('Veuillez remplir tous les champs obligatoires',
          isError: true);
      return;
    }

    if (_heureArrivee == null || _heureFin == null) {
      _afficherMessage('Veuillez sélectionner les heures d\'arrivée et de fin',
          isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Génération du PDF
      final pdf = await _genererPDF();

      // 2. Sauvegarde sur le stockage temporaire de l'appareil
      final directory = await getTemporaryDirectory();
      final file = File(
          '${directory.path}/intervention_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      // 3. Partage natif (mail, Whatsapp, etc.)
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            "Rapport d'intervention PDF généré via l'application enso estérel.",
        subject: "Rapport d'intervention - ${_entrepriseController.text}",
      );

      _afficherMessage('PDF généré et prêt à être envoyé !');
      _reinitialiserFormulaire();
    } catch (e) {
      _afficherMessage('Erreur lors de la génération/partage: $e',
          isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Fonction qui génère le PDF à partir des champs saisis
  Future<pw.Document> _genererPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // EN-TÊTE
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue800,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'RAPPORT D\'INTERVENTION',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 30),

              // INFOS GÉNÉRALES
              pw.Container(
                padding: pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('INFORMATIONS GÉNÉRALES',
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 15),
                    _buildPDFRow('Entreprise:', _entrepriseController.text),
                    _buildPDFRow('Date du jour:',
                        DateFormat('dd/MM/yyyy').format(_dateJour)),
                    _buildPDFRow(
                        'Heure d\'arrivée:', _formatHeure(_heureArrivee!)),
                    _buildPDFRow('Heure de fin:', _formatHeure(_heureFin!)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // TYPE DE PANNE
              pw.Container(
                padding: pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('TYPE DE PANNE',
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Text(_typePanneController.text,
                        style: pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ),

              pw.Spacer(),

              // PIED DE PAGE : date et heure de génération
              pw.Center(
                child: pw.Text(
                  'Document généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  /// Fonction utilitaire pour formater une ligne dans le PDF
  pw.Widget _buildPDFRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 120,
            child: pw.Text(label,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }

  /// Réinitialisation du formulaire après envoi
  void _reinitialiserFormulaire() {
    _entrepriseController.clear();
    _typePanneController.clear();
    setState(() {
      _heureArrivee = null;
      _heureFin = null;
      _dateJour = DateTime.now();
    });
  }

  /// Affiche un message (vert ou rouge) en bas de l'écran
  void _afficherMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _entrepriseController.dispose();
    _typePanneController.dispose();
    super.dispose();
  }
}
