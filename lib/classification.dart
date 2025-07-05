import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive/hive.dart';

/// Modèle pour une classification (serialisable)
class ClassificationItem {
  final String nomClient;
  final DateTime date;
  final Map<String, double> pourcentages;
  final List<String> photos;

  ClassificationItem({
    required this.nomClient,
    required this.date,
    required this.pourcentages,
    required this.photos,
  });

  Map<String, dynamic> toMap() => {
        'nomClient': nomClient,
        'date': date.toIso8601String(),
        'pourcentages': pourcentages,
        'photos': photos,
      };

  factory ClassificationItem.fromMap(Map map) => ClassificationItem(
        nomClient: map['nomClient'],
        date: DateTime.parse(map['date']),
        pourcentages: Map<String, double>.from(map['pourcentages']),
        photos: List<String>.from(map['photos']),
      );
}

class ClassificationPage extends StatefulWidget {
  @override
  State<ClassificationPage> createState() => _ClassificationPageState();
}

class _ClassificationPageState extends State<ClassificationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomClientController = TextEditingController();
  DateTime _date = DateTime.now();

  final List<String> _matieres = [
    "Métaux",
    "Bois",
    "Carton",
    "Plastique souple",
    "Plastique rigide",
    "Gravats",
    "Plâtre",
    "Refus de tri"
  ];

  Map<String, double> _pourcentages = {};
  List<XFile> _photos = [];
  List<ClassificationItem> _classifications = [];
  String _search = "";

  @override
  void initState() {
    super.initState();
    for (var m in _matieres) {
      _pourcentages[m] = 0.0;
    }
    _chargerClassifications();
  }

  double _totalPourcentage() => _pourcentages.values.fold(0.0, (a, b) => a + b);

  Future<void> _pickPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) setState(() => _photos.add(image));
  }

  void _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_totalPourcentage() != 100) {
      _showSnack("Le total doit faire 100%");
      return;
    }
    final item = ClassificationItem(
      nomClient: _nomClientController.text.trim(),
      date: _date,
      pourcentages: Map.from(_pourcentages),
      photos: _photos.map((x) => x.path).toList(),
    );
    setState(() {
      _classifications.insert(0, item);
      _nomClientController.clear();
      _photos.clear();
      _pourcentages = {for (var m in _matieres) m: 0.0};
      _date = DateTime.now();
    });
    // Sauvegarde Hive
    final box = Hive.box('classifications');
    final list = _classifications.map((e) => e.toMap()).toList();
    await box.put('all', list);

    _showSnack("Classification enregistrée !");
  }

  void _chargerClassifications() async {
    final box = Hive.box('classifications');
    final data = box.get('all', defaultValue: []);
    setState(() {
      _classifications = (data as List)
          .map((e) => ClassificationItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    });
  }

  void _showSnack(String txt) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(txt), duration: Duration(seconds: 2)),
    );
  }

  /// Générer et partager le PDF (avec nom client/date dans objet)
  Future<void> _generateAndSharePdf(ClassificationItem item) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text("Classification matière",
              style:
                  pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text("Client : ${item.nomClient}",
              style: pw.TextStyle(fontSize: 16)),
          pw.Text("Date : ${DateFormat('dd/MM/yyyy HH:mm').format(item.date)}",
              style: pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(
                    padding: pw.EdgeInsets.all(5),
                    child: pw.Text('Matière',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(5),
                    child: pw.Text('Pourcentage',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              ...item.pourcentages.entries.map((e) => pw.TableRow(
                    children: [
                      pw.Padding(
                          padding: pw.EdgeInsets.all(5), child: pw.Text(e.key)),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('${e.value.toStringAsFixed(1)} %')),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 18),
          if (item.photos.isNotEmpty) ...[
            pw.Text('Photos associées :',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: item.photos
                  .map((p) => pw.Column(
                        children: [
                          pw.Container(
                            width: 120,
                            height: 120,
                            decoration:
                                pw.BoxDecoration(border: pw.Border.all()),
                            child: pw.Image(
                              pw.MemoryImage(File(p).readAsBytesSync()),
                              fit: pw.BoxFit.cover,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(item.nomClient,
                              style: pw.TextStyle(fontSize: 12)),
                        ],
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final pdfPath =
        "${output.path}/classification_${item.nomClient}_${DateFormat('yyyyMMdd_HHmm').format(item.date)}.pdf";
    final file = File(pdfPath);
    await file.writeAsBytes(await pdf.save());

    final objet =
        "${item.nomClient} - ${DateFormat('dd/MM/yyyy HH:mm').format(item.date)}";
    final corps =
        "Bonjour,\n\nVeuillez trouver en pièce jointe la classification matière pour ${item.nomClient}.\nDate : ${DateFormat('dd/MM/yyyy HH:mm').format(item.date)}\n\nCordialement,\n";

    await Share.shareXFiles(
      [XFile(pdfPath)],
      subject: objet,
      text: corps,
    );
  }

  // Ajout bouton supprimer dans la liste
  Future<void> _supprimerClassification(int idx) async {
    setState(() {
      _classifications.removeAt(idx);
    });
    final box = Hive.box('classifications');
    final list = _classifications.map((e) => e.toMap()).toList();
    await box.put('all', list);
    _showSnack("Classification supprimée");
  }

  // --- PieChart ---
  Widget buildPieChart(Map<String, double> data) {
    final entries = data.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) return Text("Aucune donnée à afficher.");
    return Container(
      height: 260,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: PieChart(
            PieChartData(
              sections: entries
                  .asMap()
                  .map<int, PieChartSectionData>((i, e) => MapEntry(
                        i,
                        PieChartSectionData(
                          value: e.value,
                          title: '${e.key}\n${e.value.toStringAsFixed(1)}%',
                          radius: 65,
                          titleStyle: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ))
                  .values
                  .toList(),
              centerSpaceRadius: 35,
              sectionsSpace: 3,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _classifications.where((item) {
      return _search.isEmpty ||
          item.nomClient.toLowerCase().contains(_search.toLowerCase()) ||
          DateFormat('dd/MM/yyyy').format(item.date).contains(_search);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Classification matière"),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- FORMULAIRE ---
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nomClientController,
                    decoration: InputDecoration(
                      labelText: "Nom du client",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? "Nom du client requis"
                        : null,
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18),
                      SizedBox(width: 8),
                      Text(DateFormat('dd/MM/yyyy HH:mm').format(_date)),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text("Pourcentage par matière :",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._matieres.map((m) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 12),
                          Text(m,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Row(
                            children: [
                              Text(
                                "${_pourcentages[m]!.toStringAsFixed(0)} %",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo[800],
                                    fontSize: 16),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Slider(
                                  value: _pourcentages[m]!,
                                  min: 0,
                                  max: 100,
                                  divisions: 100,
                                  label:
                                      "${_pourcentages[m]!.toStringAsFixed(0)}%",
                                  activeColor: Colors.blueAccent,
                                  inactiveColor: Colors.blue[100],
                                  thumbColor: Colors.indigo[800],
                                  onChanged: (val) =>
                                      setState(() => _pourcentages[m] = val),
                                ),
                              ),
                            ],
                          ),
                          Divider(),
                        ],
                      )),
                  SizedBox(height: 10),
                  Text("Total : ${_totalPourcentage().toStringAsFixed(0)} %",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _totalPourcentage() == 100
                              ? Colors.green
                              : Colors.red)),
                  SizedBox(height: 12),
                  Text('Photos associées :',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ..._photos.map((img) => Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  File(img.path),
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.cancel, color: Colors.red),
                                onPressed: () =>
                                    setState(() => _photos.remove(img)),
                              )
                            ],
                          )),
                      GestureDetector(
                        onTap: _pickPhoto,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.grey[100],
                          ),
                          child: Icon(Icons.camera_alt,
                              size: 32, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _enregistrer,
                      icon: Icon(Icons.save),
                      label: Text("Enregistrer la classification"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // --- RECHERCHE + LISTE AVEC SUPPRESSION ---
            TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Recherche par nom ou date (ex : 15/06/2025)",
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _search = val.trim()),
            ),
            SizedBox(height: 14),
            filtered.isEmpty
                ? Text("Aucune classification trouvée",
                    style: TextStyle(color: Colors.grey))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final item = filtered[i];
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(Icons.assignment),
                          title: Text(item.nomClient),
                          subtitle: Text(
                              "Date : ${DateFormat('dd/MM/yyyy HH:mm').format(item.date)}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Visualiser PDF
                              IconButton(
                                icon: Icon(Icons.picture_as_pdf),
                                tooltip: "Visualiser PDF",
                                onPressed: () => Printing.layoutPdf(
                                  onLayout: (format) async =>
                                      (await _buildPdf(item)).save(),
                                ),
                              ),
                              // PARTAGE EMAIL
                              IconButton(
                                icon: Icon(Icons.email),
                                tooltip: "Envoyer par mail",
                                onPressed: () => _generateAndSharePdf(item),
                              ),
                              // SUPPRESSION
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                tooltip: "Supprimer",
                                onPressed: () => _supprimerClassification(
                                    _classifications.indexOf(item)),
                              ),
                            ],
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text('Détails – ${item.nomClient}'),
                                content: SizedBox(
                                  width: 330,
                                  height: 330,
                                  child: buildPieChart(item.pourcentages),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  // Pour visualiser un PDF sur mobile (hors partage)
  Future<pw.Document> _buildPdf(ClassificationItem item) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text("Classification matière",
              style:
                  pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text("Client : ${item.nomClient}",
              style: pw.TextStyle(fontSize: 16)),
          pw.Text("Date : ${DateFormat('dd/MM/yyyy HH:mm').format(item.date)}",
              style: pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(
                    padding: pw.EdgeInsets.all(5),
                    child: pw.Text('Matière',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(5),
                    child: pw.Text('Pourcentage',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              ...item.pourcentages.entries.map((e) => pw.TableRow(
                    children: [
                      pw.Padding(
                          padding: pw.EdgeInsets.all(5), child: pw.Text(e.key)),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text('${e.value.toStringAsFixed(1)} %')),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 18),
          if (item.photos.isNotEmpty) ...[
            pw.Text('Photos associées :',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: item.photos
                  .map((p) => pw.Column(
                        children: [
                          pw.Container(
                            width: 120,
                            height: 120,
                            decoration:
                                pw.BoxDecoration(border: pw.Border.all()),
                            child: pw.Image(
                              pw.MemoryImage(File(p).readAsBytesSync()),
                              fit: pw.BoxFit.cover,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(item.nomClient,
                              style: pw.TextStyle(fontSize: 12)),
                        ],
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
    return pdf;
  }
}
