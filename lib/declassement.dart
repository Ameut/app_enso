import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class DeclassementClientPage extends StatefulWidget {
  @override
  _DeclassementClientPageState createState() => _DeclassementClientPageState();
}

class _DeclassementClientPageState extends State<DeclassementClientPage> {
  double _pourcentage = 100.0; // Pourcentage du slider
  final TextEditingController _clientController =
      TextEditingController(); // Nom du client
  final TextEditingController _commentaireController =
      TextEditingController(); // Commentaire optionnel
  List<File> _images = []; // Photos sélectionnées
  final ImagePicker _picker = ImagePicker();

  // Destinataires du mail (toujours présents)
  final List<String> _destinataires = [
    'claire.lagarrigue@enso-valo.com',
    'laetitia.mazzara@enso-valo.com'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Déclassement Client',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.indigo[700],
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildJaugePourcentage(),
            SizedBox(height: 24),
            _buildChampClient(),
            SizedBox(height: 20),
            _buildSectionPhotos(),
            SizedBox(height: 20),
            _buildChampCommentaire(),
            SizedBox(height: 32),
            _buildBoutonEnvoyer(),
          ],
        ),
      ),
    );
  }

  // Widget jauge pourcentage (slider + cercle)
  Widget _buildJaugePourcentage() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pourcentage de déclassement',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: Container(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: CircularProgressIndicator(
                        value: _pourcentage / 100,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey[300],
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_pourcentage >= 80
                                ? Colors.red
                                : _pourcentage >= 50
                                    ? Colors.orange
                                    : Colors.green),
                      ),
                    ),
                    Text(
                      '${_pourcentage.toInt()}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Slider(
              value: _pourcentage,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${_pourcentage.toInt()}%',
              onChanged: (value) {
                setState(() {
                  _pourcentage = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // Champ nom du client
  Widget _buildChampClient() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations Client',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _clientController,
              decoration: InputDecoration(
                labelText: 'Nom du client *',
                hintText: 'Saisissez le nom du client',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.person, color: Colors.indigo),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Section pour prendre/choisir des photos
  Widget _buildSectionPhotos() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Photos (${_images.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _prendrePhoto(ImageSource.camera),
                    icon: Icon(Icons.camera_alt),
                    label: Text('Appareil photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _prendrePhoto(ImageSource.gallery),
                    icon: Icon(Icons.photo_library),
                    label: Text('Galerie'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[400],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_images.isNotEmpty)
              Container(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _images[index],
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _supprimerImage(index),
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Champ commentaire (optionnel)
  Widget _buildChampCommentaire() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Commentaire (optionnel)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _commentaireController,
              maxLines: 2,
              maxLength: 120,
              decoration: InputDecoration(
                hintText: 'Ajoutez un commentaire (max 2 lignes)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.comment, color: Colors.indigo),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bouton principal d'envoi (mail pré-rempli)
  Widget _buildBoutonEnvoyer() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _envoyerParMailPreRempli, // La méthode d'envoi
        icon: Icon(Icons.send, color: Colors.white),
        label: Text(
          'Envoyer le déclassement',
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

  // Prendre ou sélectionner une photo
  Future<void> _prendrePhoto(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _images.add(File(image.path));
        });
      }
    } catch (e) {
      _afficherMessage('Erreur lors de la prise de photo: $e');
    }
  }

  // Supprimer une photo sélectionnée
  void _supprimerImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  /// ======== CŒUR : ENVOI PAR MAIL PRÉ-REMPLI AVEC LES DEUX ADRESSES ========== ///
  Future<void> _envoyerParMailPreRempli() async {
    if (_clientController.text.isEmpty) {
      _afficherMessage('Veuillez saisir le nom du client');
      return;
    }
    if (_images.isEmpty) {
      _afficherMessage('Ajoutez au moins une photo');
      return;
    }

    // -------- Objet du mail personnalisé ---------
    // Exemple : "Déclassement Dupont - 05/07/2025 - 86%"
    String dateString = "${DateTime.now().day.toString().padLeft(2, '0')}/"
        "${DateTime.now().month.toString().padLeft(2, '0')}/"
        "${DateTime.now().year}";
    String objet =
        "Déclassement ${_clientController.text.trim()} - $dateString - ${_pourcentage.toInt()}%";

    // Format date et heure pour le corps du mail
    String heureString = "${DateTime.now().hour.toString().padLeft(2, '0')}:"
        "${DateTime.now().minute.toString().padLeft(2, '0')}";
    String corps = "Déclassement client\n"
        "Nom du client : ${_clientController.text}\n"
        "Pourcentage de déclassement : ${_pourcentage.toInt()}%\n"
        "Date : $dateString $heureString\n"
        "${_commentaireController.text.isNotEmpty ? 'Commentaire : ${_commentaireController.text}\n' : ''}"
        "\nÀ envoyer à : ${_destinataires.join(', ')}\n"
        "Envoyé via l'application Enso Estérel.";

    // Prépare les photos à partager
    List<XFile> fichiers = _images.map((f) => XFile(f.path)).toList();

    // Envoi avec share_plus
    await Share.shareXFiles(
      fichiers,
      subject: objet, // l’objet du mail avec toutes les infos demandées
      text: corps,
    );
  }

  // Affiche une snackbar (message d'erreur ou confirmation)
  void _afficherMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _clientController.dispose();
    _commentaireController.dispose();
    super.dispose();
  }
}
