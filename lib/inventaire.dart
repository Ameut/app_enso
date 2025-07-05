// inventaire.dart
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

class PageInventaire extends StatefulWidget {
  const PageInventaire({super.key});
  @override
  State<PageInventaire> createState() => _PageInventaireState();
}

class _PageInventaireState extends State<PageInventaire> {
  // Liste de matières
  final List<Map<String, dynamic>> matieres = [
    {'nom': 'Carton', 'vrac': true, 'coef': 0.06, 'balle': true},
    {'nom': 'Films plastiques', 'vrac': true, 'coef': 0.02, 'balle': true},
    {'nom': 'Plastique rigide', 'vrac': true, 'coef': 0.08, 'balle': true},
    {'nom': 'Papier', 'vrac': true, 'coef': 0.3, 'balle': true},
    {'nom': 'Bois', 'vrac': true, 'coef': 0.3, 'balle': false},
    {'nom': 'Métaux', 'vrac': true, 'coef': 0.18, 'balle': false},
    {'nom': 'Gravats', 'vrac': true, 'coef': 1.4, 'balle': false},
    {'nom': 'Fines', 'vrac': true, 'coef': 0.75, 'balle': false},
    {'nom': 'Refus', 'vrac': true, 'coef': 0.8, 'balle': true},
    {'nom': 'Plâtre', 'vrac': true, 'coef': 1.1, 'balle': false},
  ];

  final _formKey = GlobalKey<FormState>();
  final TextEditingController nomController = TextEditingController();
  DateTime date = DateTime.now();

  Map<String, Map<String, TextEditingController>> tonnages = {};

  @override
  void initState() {
    super.initState();
    // Init contrôleurs pour chaque matière
    for (var mat in matieres) {
      tonnages[mat['nom']] = {};
      if (mat['vrac']) tonnages[mat['nom']]!['vrac'] = TextEditingController();
      if (mat['balle'] == true)
        tonnages[mat['nom']]!['balle'] = TextEditingController();
    }
  }

  @override
  void dispose() {
    nomController.dispose();
    for (var mat in matieres) {
      tonnages[mat['nom']]!['vrac']?.dispose();
      tonnages[mat['nom']]!['balle']?.dispose();
    }
    super.dispose();
  }

  String get dateStr => DateFormat('dd/MM/yyyy – HH:mm').format(date);

  double calculTotal(double coef, String vrac) {
    double v = double.tryParse(vrac.replaceAll(',', '.')) ?? 0;
    return v * coef;
  }

  // === GESTION DES PERMISSIONS DE STOCKAGE ===
  /// Demande les bonnes permissions selon la version d'Android
  Future<bool> checkAndRequestStoragePermission() async {
    if (Platform.isAndroid) {
      // Android 11+ : demande MANAGE_EXTERNAL_STORAGE
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }
      if (await Permission.storage.isGranted) {
        return true;
      }
      // Demande toutes les permissions nécessaires
      final statuses = await [
        Permission.storage,
        Permission.manageExternalStorage,
      ].request();

      // Vérifie au moins une acceptée
      if (statuses[Permission.manageExternalStorage]?.isGranted == true ||
          statuses[Permission.storage]?.isGranted == true) {
        return true;
      }

      // Affiche un message si refus
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Permission stockage refusée. Impossible d'exporter le fichier.")),
        );
      }
      return false;
    }
    return true;
  }

  // === EXPORT CSV ===
  Future<void> exportCSVAndShareMail() async {
    if (!await checkAndRequestStoragePermission()) return;

    List<List<String>> rows = [
      ['Nom', 'Date', 'Matière', 'Vrac (m³)', 'Coef', 'Total (t)', 'Nb balles']
    ];
    for (var mat in matieres) {
      final matiere = mat['nom'];
      final coef = mat['coef'];
      final vrac = mat['vrac'] ? (tonnages[matiere]!['vrac']?.text ?? '') : '';
      final balle =
          mat['balle'] == true ? (tonnages[matiere]!['balle']?.text ?? '') : '';
      final total = calculTotal(coef, vrac);
      rows.add([
        nomController.text.trim(),
        dateStr,
        matiere,
        vrac,
        coef.toString(),
        total.toStringAsFixed(2),
        balle,
      ]);
    }
    String csvData = const ListToCsvConverter().convert(rows);

    // Sauvegarde le CSV dans le dossier Documents de l'app (toujours accessible)
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/inventaire_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    if (await file.exists()) {
      await Share.shareXFiles([XFile(path)],
          text: "Inventaire Enso Esterel CSV");
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur à la création du CSV : $path")),
        );
      }
    }
  }

  // === EXPORT PDF ===
  Future<void> exportPDF({bool openFile = false}) async {
    if (!await checkAndRequestStoragePermission()) return;

    final pdf = pw.Document();
    final List<List<String>> rows = [
      ['Matière', 'Vrac (m³)', 'Coef', 'Total (t)', 'Nb balles']
    ];
    for (var mat in matieres) {
      final matiere = mat['nom'];
      final coef = mat['coef'];
      final vrac = mat['vrac'] ? (tonnages[matiere]!['vrac']?.text ?? '') : '';
      final balle =
          mat['balle'] == true ? (tonnages[matiere]!['balle']?.text ?? '') : '';
      final total = calculTotal(coef, vrac);
      rows.add([
        matiere,
        vrac,
        coef.toString(),
        total.toStringAsFixed(2),
        balle,
      ]);
    }

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Inventaire',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.Text('Nom: ${nomController.text.trim()}'),
            pw.Text('Date: $dateStr'),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: rows[0],
              data: rows.sublist(1),
            ),
          ],
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/inventaire_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());

    if (await file.exists()) {
      if (openFile) {
        await OpenFile.open(path);
      } else {
        await Share.shareXFiles([XFile(path)],
            text: "Inventaire Enso Esterel PDF");
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur à la création du PDF : $path")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final matieresAvecBalle =
        matieres.where((m) => m['balle'] == true).toList();
    final matieresSansBalle =
        matieres.where((m) => m['balle'] == false).toList();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xffe3f2fd), Color(0xfff9fbe7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Inventaire'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Formulaire principal
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 6,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              Text(
                                "Nouvel inventaire",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.indigo[900]),
                              ),
                              const SizedBox(height: 16),
                              // Saisie du nom
                              TextFormField(
                                controller: nomController,
                                decoration: InputDecoration(
                                  labelText: 'Nom de la personne',
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.auto,
                                ),
                                validator: (val) => val == null || val.isEmpty
                                    ? "Champ obligatoire"
                                    : null,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 16),
                              // Sélection de la date et de l'heure
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 20),
                                  const SizedBox(width: 10),
                                  Text('Date & heure : $dateStr'),
                                  const Spacer(),
                                  OutlinedButton.icon(
                                    icon: const Icon(
                                        Icons.edit_calendar_outlined,
                                        size: 20),
                                    label: const Text('Modifier'),
                                    onPressed: () async {
                                      DateTime? picked = await showDatePicker(
                                        context: context,
                                        initialDate: date,
                                        firstDate: DateTime(2022),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        TimeOfDay? time = await showTimePicker(
                                          context: context,
                                          initialTime:
                                              TimeOfDay.fromDateTime(date),
                                        );
                                        if (time != null) {
                                          setState(() {
                                            date = DateTime(
                                              picked.year,
                                              picked.month,
                                              picked.day,
                                              time.hour,
                                              time.minute,
                                            );
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      // --- Tableau matières avec balles ---
                      _MatiereTable(
                        title: "Matières avec balles",
                        matieres: matieresAvecBalle,
                        tonnages: tonnages,
                        calculTotal: calculTotal,
                        withBalles: true,
                      ),
                      const SizedBox(height: 12),
                      // --- Tableau matières sans balles ---
                      _MatiereTable(
                        title: "Matières sans balles",
                        matieres: matieresSansBalle,
                        tonnages: tonnages,
                        calculTotal: calculTotal,
                        withBalles: false,
                      ),
                      const SizedBox(height: 28),
                      // --- Boutons d'export PDF / CSV ---
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('Exporter PDF'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.indigo[700],
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(fontSize: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 5,
                              ),
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  showModalBottomSheet(
                                    context: context,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(18)),
                                    ),
                                    builder: (_) => SafeArea(
                                      child: Wrap(
                                        children: [
                                          ListTile(
                                            leading: const Icon(Icons.mail),
                                            title: const Text("Envoyer PDF"),
                                            onTap: () async {
                                              Navigator.pop(context);
                                              await exportPDF();
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.save),
                                            title:
                                                const Text("Enregistrer PDF"),
                                            onTap: () async {
                                              Navigator.pop(context);
                                              await exportPDF(openFile: true);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.table_chart),
                              label: const Text('Exporter CSV'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.teal[700],
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(fontSize: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 5,
                              ),
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  await exportCSVAndShareMail();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// --- COMPOSANT POUR L’AFFICHAGE DES TABLEAUX DE MATIÈRES ---
class _MatiereTable extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> matieres;
  final Map<String, Map<String, TextEditingController>> tonnages;
  final double Function(double, String) calculTotal;
  final bool withBalles;

  const _MatiereTable({
    required this.title,
    required this.matieres,
    required this.tonnages,
    required this.calculTotal,
    required this.withBalles,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.left,
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: [
                  const DataColumn(label: Text('Matière')),
                  const DataColumn(label: Text('Vrac (m³)')),
                  const DataColumn(label: Text('Coef')),
                  const DataColumn(label: Text('Total (t)')),
                  if (withBalles) const DataColumn(label: Text('Nb balles')),
                ],
                rows: matieres.map((mat) {
                  final matiere = mat['nom'];
                  final coef = mat['coef'];
                  final vracController = tonnages[matiere]!['vrac'];
                  final balleController =
                      mat['balle'] == true ? tonnages[matiere]!['balle'] : null;
                  final vrac = vracController?.text ?? '';
                  final balle = balleController?.text ?? '';
                  final total = calculTotal(coef, vrac);
                  return DataRow(
                    cells: [
                      DataCell(Text(matiere)),
                      DataCell(SizedBox(
                        width: 75,
                        child: TextFormField(
                          controller: vracController,
                          decoration: const InputDecoration(
                            hintText: 'm³',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (v) =>
                              (context as Element).markNeedsBuild(),
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            if (double.tryParse(v.replaceAll(',', '.')) == null)
                              return 'Nombre';
                            return null;
                          },
                        ),
                      )),
                      DataCell(Text(coef.toString())),
                      DataCell(Text(total.toStringAsFixed(2))),
                      if (withBalles)
                        DataCell(SizedBox(
                          width: 75,
                          child: TextFormField(
                            controller: balleController,
                            decoration: const InputDecoration(
                              hintText: 'Nb',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (v) =>
                                (context as Element).markNeedsBuild(),
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              if (int.tryParse(v) == null) return 'Nombre';
                              return null;
                            },
                          ),
                        )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
