import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

// --- IMPORTS INTERNES ---
import 'page_rappel.dart';
import 'classification.dart';
import 'declassement.dart';
import 'intervention.dart';

// --- MAIN : Initialisation de Hive + lancement appli ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
    await Hive.openBox('classifications');
  } catch (e, stacktrace) {
    print('Erreur lors de l\'initialisation de Hive : $e');
    print(stacktrace);
  }
  runApp(const MyApp());
}

// --- Widget racine de l'appli ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      home: const HomePage(),
    );
  }
}

// --- Page principale avec navigation par onglets ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  // Liste de toutes les pages de ton appli
  static final List<Widget> _pages = [
    const PageAccueil(key: ValueKey('Accueil')),
    const PageInventaire(key: ValueKey('Inventaire')),
    PageRappel(),
    ClassificationPage(),
    DeclassementClientPage(),
    InterventionPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          setState(() => _selectedIndex = index);
        },
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onTabTapped,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Accueil'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2), label: 'Inventaire'),
          NavigationDestination(icon: Icon(Icons.alarm), label: 'Rappel'),
          NavigationDestination(
              icon: Icon(Icons.category), label: 'Classification'),
          NavigationDestination(
              icon: Icon(Icons.trending_down), label: 'Déclassement'),
          NavigationDestination(
              icon: Icon(Icons.engineering), label: 'Intervention'),
        ],
      ),
    );
  }
}

// --- PAGE ACCUEIL (page d'accueil simple et épurée) ---
class PageAccueil extends StatelessWidget {
  const PageAccueil({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: "logo",
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Image.asset(
                  'assets/images/fond.png',
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "Enso Estérel",
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Colors.indigo[800],
                letterSpacing: 1,
                shadows: [
                  Shadow(
                    blurRadius: 8,
                    color: Colors.black26,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AnimatedOpacity(
              opacity: 1,
              duration: const Duration(seconds: 1),
              child: Text(
                "Application de gestion des déchets",
                style: TextStyle(
                  color: Colors.blueGrey[600],
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- PAGE INVENTAIRE ---
class PageInventaire extends StatefulWidget {
  const PageInventaire({super.key});
  @override
  State<PageInventaire> createState() => _PageInventaireState();
}

class _PageInventaireState extends State<PageInventaire> {
  // Matières en vrac et en balles avec coefficients pour calcul des tonnages
  final List<Map<String, dynamic>> matieresVrac = [
    {'nom': 'Carton', 'coef': 0.06},
    {'nom': 'Films plastiques', 'coef': 0.02},
    {'nom': 'Plastique rigide', 'coef': 0.08},
    {'nom': 'Papier', 'coef': 0.25},
    {'nom': 'Refus de tri', 'coef': 0.8},
    {'nom': 'Bois', 'coef': 0.3},
    {'nom': 'Métaux', 'coef': 0.18},
    {'nom': 'Gravats', 'coef': 1.4},
    {'nom': 'Fines', 'coef': 0.75},
    {'nom': 'Plâtre', 'coef': 1.1},
  ];
  final List<Map<String, dynamic>> matieresBalle = [
    {'nom': 'Carton', 'coef': 0.8},
    {'nom': 'Petite balle de carton'},
    {'nom': 'Films plastiques', 'coef': 0.62},
    {'nom': 'Petite balle plastique'},
    {'nom': 'Plastique rigide', 'coef': 0.25},
    {'nom': 'Papier', 'coef': 0.7},
    {'nom': 'Refus', 'coef': 0.8},
  ];

  // Contrôleurs pour le formulaire
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nomController = TextEditingController();
  DateTime date = DateTime.now();
  Map<String, Map<String, TextEditingController>> tonnages = {};

  @override
  void initState() {
    super.initState();
    // On crée un contrôleur pour chaque matière/colonne (vrac, balle)
    for (var mat in matieresVrac) {
      tonnages[mat['nom']] = {};
      tonnages[mat['nom']]!['vrac'] = TextEditingController();
    }
    for (var mat in matieresBalle) {
      tonnages[mat['nom']] ??= {};
      tonnages[mat['nom']]!['balle'] = TextEditingController();
    }
  }

  @override
  void dispose() {
    nomController.dispose();
    for (var ctrl in tonnages.values) {
      ctrl['vrac']?.dispose();
      ctrl['balle']?.dispose();
    }
    super.dispose();
  }

  String get dateStr => DateFormat('dd/MM/yyyy - HH:mm').format(date);

  String get dateForFilename => DateFormat('yyyy-MM-dd_HH-mm').format(date);

  // Calcul du tonnage total pour chaque matière
  double calculTotal(double? coef, String valeur) {
    if (coef == null) return 0;
    double v = double.tryParse(valeur.replaceAll(',', '.')) ?? 0;
    return v * coef;
  }

  // Chemin temporaire pour enregistrer PDF/CSV
  Future<String> getSavePath(String filename) async {
    var tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/$filename';
  }

  // -------------- FONCTION PRINCIPALE D'EXPORT PDF + CSV + PARTAGE --------------
  Future<void> exportPDFAndCSVAndShare() async {
    if (nomController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez saisir votre nom")),
        );
      }
      return;
    }

    final String nom = nomController.text.trim();
    final pdf = pw.Document();

    // Construction des tableaux pour PDF/CSV
    final List<List<String>> rowsVrac = [
      ['Matière', 'Vrac (m³)', 'Coef', 'Total (t)']
    ];
    for (var mat in matieresVrac) {
      final matiere = mat['nom'];
      final coef = mat['coef'];
      final vrac = tonnages[matiere]!['vrac']?.text ?? '';
      final total = calculTotal(coef, vrac);
      rowsVrac.add([
        matiere,
        vrac,
        coef.toString(),
        total.toStringAsFixed(2),
      ]);
    }

    final List<List<String>> rowsBalle = [
      ['Matière', 'Nb balles', 'Coef', 'Total (t)']
    ];
    for (var mat in matieresBalle) {
      final matiere = mat['nom'];
      final balle = tonnages[matiere]!['balle']?.text ?? '';
      final coef = mat.containsKey('coef') ? mat['coef'] as double? : null;
      final total = (coef != null && balle.isNotEmpty)
          ? (double.tryParse(balle) ?? 0) * coef
          : null;
      rowsBalle.add([
        matiere,
        balle,
        coef?.toString() ?? '',
        (total != null) ? total.toStringAsFixed(2) : ''
      ]);
    }

    // Création du PDF avec tous les tableaux
    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Inventaire Enso Estérel',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Nom: $nom',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Date: $dateStr',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Text('Matières Vrac',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: rowsVrac[0],
            data: rowsVrac.sublist(1),
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.center,
          ),
          pw.SizedBox(height: 25),
          pw.Text('Tableau Balles',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: rowsBalle[0],
            data: rowsBalle.sublist(1),
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.center,
          ),
        ],
      ),
    );

    try {
      String pdfFilename = 'Inventaire_${nom}_$dateForFilename.pdf';
      String csvFilename = 'Inventaire_${nom}_$dateForFilename.csv';
      String pdfPath = await getSavePath(pdfFilename);
      String csvPath = await getSavePath(csvFilename);

      // Enregistre le PDF
      File pdfFile = File(pdfPath);
      await pdfFile.writeAsBytes(await pdf.save());

      // Génère le CSV
      String csvData = const ListToCsvConverter().convert(rowsVrac) +
          '\n\n' +
          const ListToCsvConverter().convert(rowsBalle);
      File csvFile = File(csvPath);
      await csvFile.writeAsString(csvData);

      // Sujet (objet) + corps du mail/message
      String emailSubject =
          'Inventaire $nom - ${DateFormat('dd/MM/yyyy').format(date)}';
      String emailBody =
          'Inventaire de fin de mois réalisé pour le nom inscrit : $nom.\n\nFichiers joints : PDF & CSV.\nDate : $dateStr';

      // Ouvre le partage avec PDF + CSV en pièces jointes
      await Share.shareXFiles(
        [XFile(pdfFile.path), XFile(csvFile.path)],
        subject: emailSubject,
        text: emailBody,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PDF et CSV partagés avec succès.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors du partage : $e")),
        );
      }
    }
  }

  // --- UI PRINCIPALE DE LA PAGE INVENTAIRE ---
  @override
  Widget build(BuildContext context) {
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
                      // Carte du formulaire
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
                              TextFormField(
                                controller: nomController,
                                decoration: InputDecoration(
                                  labelText: 'Votre nom',
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
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text('Date & heure : $dateStr')),
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
                      // Tableau des matières vrac
                      _MatiereVracTable(
                        matieres: matieresVrac,
                        tonnages: tonnages,
                        calculTotal: calculTotal,
                      ),
                      const SizedBox(height: 16),
                      // Tableau des balles
                      _MatiereBalleTable(
                        matieres: matieresBalle,
                        tonnages: tonnages,
                      ),
                      const SizedBox(height: 28),
                      // --------- BOUTON UNIQUE PARTAGE PDF + CSV ---------
                      ElevatedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text('Partager PDF + CSV'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            await exportPDFAndCSVAndShare();
                          }
                        },
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

// --- TABLEAU DES MATIERES EN VRAC ---
class _MatiereVracTable extends StatelessWidget {
  final List<Map<String, dynamic>> matieres;
  final Map<String, Map<String, TextEditingController>> tonnages;
  final double Function(double, String) calculTotal;
  const _MatiereVracTable({
    required this.matieres,
    required this.tonnages,
    required this.calculTotal,
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
            const Text(
              "Matières Vrac",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                columns: const [
                  DataColumn(
                      label: Text('Matière',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Vrac (m³)',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Coef',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Total (t)',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: matieres.map((mat) {
                  final matiere = mat['nom'];
                  final coef = mat['coef'];
                  final vracController = tonnages[matiere]!['vrac'];
                  final vrac = vracController?.text ?? '';
                  final total = coef != null ? calculTotal(coef, vrac) : 0.0;
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
                      DataCell(Text(total.toStringAsFixed(2),
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.indigo[700]))),
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

// --- TABLEAU DES BALLES ---
class _MatiereBalleTable extends StatelessWidget {
  final List<Map<String, dynamic>> matieres;
  final Map<String, Map<String, TextEditingController>> tonnages;

  const _MatiereBalleTable({
    required this.matieres,
    required this.tonnages,
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
            const Text(
              "Tableau Balles",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                columns: const [
                  DataColumn(
                      label: Text('Matière',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Nb balles',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Coef',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Total (t)',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: matieres.map((mat) {
                  final matiere = mat['nom'];
                  final coef =
                      mat.containsKey('coef') ? mat['coef'] as double? : null;
                  final balleController = tonnages[matiere]!['balle'];
                  final balle = balleController?.text ?? '';
                  final total = (coef != null && balle.isNotEmpty)
                      ? (double.tryParse(balle) ?? 0) * coef
                      : null;
                  return DataRow(
                    cells: [
                      DataCell(Text(matiere)),
                      DataCell(
                        SizedBox(
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
                                decimal: false),
                            onChanged: (v) =>
                                (context as Element).markNeedsBuild(),
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              if (int.tryParse(v) == null) return 'Nombre';
                              return null;
                            },
                          ),
                        ),
                      ),
                      DataCell(Text(coef?.toString() ?? '')),
                      DataCell(
                        Text(
                          (total != null) ? total.toStringAsFixed(2) : '',
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.indigo[700]),
                        ),
                      ),
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
