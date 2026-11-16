import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';


void main() {
  runApp(const SmartStorageApp());
}

// ================= APP =================

class SmartStorageApp extends StatelessWidget {
  const SmartStorageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Storage Manager',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
      ),
      home: const StorageHome(),
    );
  }
}

// ================= HOME =================

class StorageHome extends StatefulWidget {
  const StorageHome({super.key});

  @override
  State<StorageHome> createState() => _StorageHomeState();
}

class _StorageHomeState extends State<StorageHome> {
  int totalFiles = 0;
  int totalSize = 0;

  Future<void> refreshStats() async {
    final prefs = await SharedPreferences.getInstance();

    final categories = ['Images', 'Videos', 'Documents'];

    int files = 0;
    int size = 0;

    for (final category in categories) {
      final paths = prefs.getStringList(category) ?? [];

      for (final path in paths) {
        final file = File(path);

        if (await file.exists()) {
          files++;
          size += await file.length();
        }
      }
    }

    if (!mounted) return;

    setState(() {
      totalFiles = files;
      totalSize = size;
    });
  }

  @override
  void initState() {
    super.initState();
    refreshStats();
  }

  String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Widget categoryCard(
      String title,
      IconData icon,
      Color color,
      ) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryPage(title: title),
            ),
          );

          refreshStats();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Storage Manager'),
      ),
      body: RefreshIndicator(
        onRefresh: refreshStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Storage',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.folder, size: 35),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$totalFiles Files',
                              style: const TextStyle(fontSize: 18),
                            ),
                            Text(formatSize(totalSize)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Categories',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            categoryCard(
              'Images',
              Icons.image,
              Colors.purple,
            ),
            categoryCard(
              'Videos',
              Icons.video_library,
              Colors.red,
            ),
            categoryCard(
              'Documents',
              Icons.description,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

// ================= CATEGORY PAGE =================

class CategoryPage extends StatefulWidget {
  final String title;

  const CategoryPage({
    super.key,
    required this.title,
  });

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  List<PlatformFile> selectedFiles = [];

  Set<String> selectedPaths = {};

  bool selectionMode = false;

  String searchQuery = '';

  String sortBy = 'Name A-Z';

  final TextEditingController searchController =
  TextEditingController();

  // ================= INIT =================

  @override
  void initState() {
    super.initState();
    loadFiles();
  }

  // ================= PICK FILES =================

  Future<void> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );

    if (result == null) return;

    final allowedExtensions = {
      'Images': ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      'Videos': ['mp4', 'mkv', 'mov', 'avi'],
      'Documents': [
        'pdf',
        'doc',
        'docx',
        'txt',
        'xlsx',
        'pptx',
      ],
    };

    final extensions = allowedExtensions[widget.title];

    final filteredFiles = result.files.where((file) {
      if (extensions == null) return true;

      final extension = file.extension?.toLowerCase();

      return extension != null &&
          extensions.contains(extension);
    }).toList();

    final existingPaths = selectedFiles
        .map((file) => file.path)
        .whereType<String>()
        .toSet();

    final newFiles = filteredFiles.where((file) {
      return file.path != null &&
          !existingPaths.contains(file.path);
    }).toList();

    setState(() {
      selectedFiles.addAll(newFiles);
    });

    await saveFiles();
  }

  // ================= SAVE =================

  Future<void> saveFiles() async {
    final prefs = await SharedPreferences.getInstance();

    final paths = selectedFiles
        .map((file) => file.path)
        .whereType<String>()
        .toList();

    await prefs.setStringList(widget.title, paths);
  }

  // ================= LOAD =================

  Future<void> loadFiles() async {
    final prefs = await SharedPreferences.getInstance();

    final paths = prefs.getStringList(widget.title) ?? [];

    final files = <PlatformFile>[];

    for (final path in paths) {
      final file = File(path);

      if (await file.exists()) {
        final size = await file.length();

        files.add(
          PlatformFile(
            name: path.split(RegExp(r'[\\/]')).last,
            size: size,
            path: path,
          ),
        );
      }
    }

    if (!mounted) return;

    setState(() {
      selectedFiles = files;
    });
  }

  // ================= FILE SIZE =================

  String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // ================= SELECTION =================

  void toggleSelection(String path) {
    setState(() {
      if (selectedPaths.contains(path)) {
        selectedPaths.remove(path);
      } else {
        selectedPaths.add(path);
      }

      selectionMode = selectedPaths.isNotEmpty;
    });
  }

  void selectAll() {
    setState(() {
      selectedPaths = selectedFiles
          .map((file) => file.path)
          .whereType<String>()
          .toSet();

      selectionMode = selectedPaths.isNotEmpty;
    });
  }

  void clearSelection() {
    setState(() {
      selectedPaths.clear();
      selectionMode = false;
    });
  }

  // ================= DELETE SELECTED =================

  Future<void> deleteSelectedFiles() async {
    setState(() {
      selectedFiles.removeWhere(
            (file) =>
        file.path != null &&
            selectedPaths.contains(file.path),
      );

      selectedPaths.clear();
      selectionMode = false;
    });

    await saveFiles();
  }

  // ================= DELETE SINGLE =================

  Future<void> deleteSingleFile(PlatformFile file) async {
    setState(() {
      selectedFiles.remove(file);

      if (file.path != null) {
        selectedPaths.remove(file.path);
      }

      selectionMode = selectedPaths.isNotEmpty;
    });

    await saveFiles();
  }

  // ================= SORT =================

  List<PlatformFile> get filteredFiles {
    List<PlatformFile> files = selectedFiles.where((file) {
      return file.name
          .toLowerCase()
          .contains(searchQuery.toLowerCase());
    }).toList();

    switch (sortBy) {
      case 'Name A-Z':
        files.sort((a, b) => a.name.compareTo(b.name));
        break;

      case 'Name Z-A':
        files.sort((a, b) => b.name.compareTo(a.name));
        break;

      case 'Small to Large':
        files.sort((a, b) => a.size.compareTo(b.size));
        break;

      case 'Large to Small':
        files.sort((a, b) => b.size.compareTo(a.size));
        break;
    }

    return files;
  }

  // ================= FILE TILE =================

  Widget fileTile(PlatformFile file) {
    return ListTile(
      leading: Checkbox(
        value: file.path != null &&
            selectedPaths.contains(file.path),
        onChanged: file.path == null
            ? null
            : (value) {
          toggleSelection(file.path!);
        },
      ),

      title: Text(
        file.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),

      subtitle: Text(formatSize(file.size)),

      trailing: IconButton(
        icon: const Icon(
          Icons.delete,
          color: Colors.red,
        ),
        onPressed: () {
          deleteSingleFile(file);
        },
      ),

      onTap: () async {
        if (file.path == null) return;

        if (selectionMode) {
          toggleSelection(file.path!);
        } else {
          await OpenFilex.open(file.path!);
        }
      },

      onLongPress: () {
        if (file.path != null) {
          toggleSelection(file.path!);
        }
      },
    );
  }

  // ================= DISPOSE =================

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    final files = filteredFiles;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectionMode
              ? '${selectedPaths.length} Selected'
              : widget.title,
        ),

        actions: [
          IconButton(
            tooltip: 'Add Files',
            icon: const Icon(Icons.add),
            onPressed: pickFiles,
          ),

          IconButton(
            tooltip: 'Select All',
            icon: const Icon(Icons.select_all),
            onPressed: selectAll,
          ),

          IconButton(
            tooltip: 'Delete Selected',
            icon: const Icon(Icons.delete),
            onPressed: selectedPaths.isEmpty
                ? null
                : deleteSelectedFiles,
          ),

          if (selectionMode)
            IconButton(
              tooltip: 'Clear Selection',
              icon: const Icon(Icons.close),
              onPressed: clearSelection,
            ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Search files...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            child: Row(
              children: [
                const Text('Sort by:'),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    value: sortBy,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'Name A-Z',
                        child: Text('Name A-Z'),
                      ),
                      DropdownMenuItem(
                        value: 'Name Z-A',
                        child: Text('Name Z-A'),
                      ),
                      DropdownMenuItem(
                        value: 'Small to Large',
                        child: Text('Small to Large'),
                      ),
                      DropdownMenuItem(
                        value: 'Large to Small',
                        child: Text('Large to Small'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        sortBy = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          Expanded(
            child: files.isEmpty
                ? const Center(
              child: Text(
                'No files found.\nTap + to add files.',
                textAlign: TextAlign.center,
              ),
            )
                : ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];

                return fileTile(file);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ================= ADVANCED STORAGE FEATURES =================



// ================= DUPLICATE FILE DETECTION =================

class DuplicateFileDetector {
  static Future<Map<String, List<String>>> findDuplicates(
      List<String> paths,
      ) async {
    final Map<String, List<String>> hashes = {};

    for (final path in paths) {
      final file = File(path);

      if (!await file.exists()) continue;

      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();

      hashes.putIfAbsent(hash, () => []);
      hashes[hash]!.add(path);
    }

    hashes.removeWhere((key, value) => value.length < 2);

    return hashes;
  }
}

// ================= FILE DETAILS =================

class AdvancedFileDetails {
  static Future<Map<String, dynamic>> getDetails(
      String path,
      ) async {
    final file = File(path);

    if (!await file.exists()) {
      return {'Error': 'File not found'};
    }

    final stat = await file.stat();

    return {
      'Name': path.split(RegExp(r'[\\/]')).last,
      'Path': path,
      'Size': '${(stat.size / 1024).toStringAsFixed(2)} KB',
      'Modified': stat.modified.toString(),
      'Type': path.split('.').last,
    };
  }
}

// ================= FAVORITES =================

class AdvancedFavorites {
  static const String key = 'advanced_favorites';

  static Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? [];
  }

  static Future<void> addFavorite(String path) async {
    final prefs = await SharedPreferences.getInstance();

    final favorites = prefs.getStringList(key) ?? [];

    if (!favorites.contains(path)) {
      favorites.add(path);
    }

    await prefs.setStringList(key, favorites);
  }

  static Future<void> removeFavorite(String path) async {
    final prefs = await SharedPreferences.getInstance();

    final favorites = prefs.getStringList(key) ?? [];

    favorites.remove(path);

    await prefs.setStringList(key, favorites);
  }
}

// ================= RECENT FILES =================

class AdvancedRecentFiles {
  static const String key = 'advanced_recent_files';

  static Future<List<String>> getRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? [];
  }

  static Future<void> addRecentFile(String path) async {
    final prefs = await SharedPreferences.getInstance();

    final recent = prefs.getStringList(key) ?? [];

    recent.remove(path);
    recent.insert(0, path);

    if (recent.length > 20) {
      recent.removeRange(20, recent.length);
    }

    await prefs.setStringList(key, recent);
  }
}

// ================= STORAGE ANALYTICS =================

class AdvancedStorageAnalytics {
  static Future<Map<String, int>> calculate(
      List<String> paths,
      ) async {
    int totalSize = 0;
    int totalFiles = 0;

    for (final path in paths) {
      final file = File(path);

      if (await file.exists()) {
        totalSize += await file.length();
        totalFiles++;
      }
    }

    return {
      'Total Files': totalFiles,
      'Total Size Bytes': totalSize,
    };
  }
}

// ================= FILE PREVIEW =================

class AdvancedFilePreview extends StatelessWidget {
  final String path;

  const AdvancedFilePreview({
    super.key,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    final extension = path.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif', 'webp']
        .contains(extension)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Image Preview')),
        body: Center(
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    if (extension == 'txt') {
      return Scaffold(
        appBar: AppBar(title: const Text('Text Preview')),
        body: FutureBuilder<String>(
          future: File(path).readAsString(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(snapshot.data!),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('File Preview')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => OpenFilex.open(path),
          child: const Text('Open File'),
        ),
      ),
    );
  }
}

// ================= ADVANCED FEATURES PAGE =================

class AdvancedFeaturesPage extends StatefulWidget {
  const AdvancedFeaturesPage({super.key});

  @override
  State<AdvancedFeaturesPage> createState() =>
      _AdvancedFeaturesPageState();
}

class _AdvancedFeaturesPageState
    extends State<AdvancedFeaturesPage> {
  List<String> paths = [];
  Map<String, List<String>> duplicates = {};
  Map<String, int> analytics = {};

  @override
  void initState() {
    super.initState();
    loadAdvancedData();
  }

  Future<void> loadAdvancedData() async {
    final prefs = await SharedPreferences.getInstance();

    final allPaths = <String>[];

    for (final category in [
      'Images',
      'Videos',
      'Documents',
    ]) {
      allPaths.addAll(
        prefs.getStringList(category) ?? [],
      );
    }

    final duplicateData =
    await DuplicateFileDetector.findDuplicates(allPaths);

    final analyticsData =
    await AdvancedStorageAnalytics.calculate(allPaths);

    if (!mounted) return;

    setState(() {
      paths = allPaths;
      duplicates = duplicateData;
      analytics = analyticsData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Features'),
      ),
      body: RefreshIndicator(
        onRefresh: loadAdvancedData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Storage Analytics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.storage),
                title: Text(
                  'Files: ${analytics['Total Files'] ?? 0}',
                ),
                subtitle: Text(
                  'Size: ${((analytics['Total Size Bytes'] ?? 0) / 1024 / 1024).toStringAsFixed(2)} MB',
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Duplicate Files',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (duplicates.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('No duplicate files found'),
                ),
              ),
            ...duplicates.values.map(
                  (files) => Card(
                child: ExpansionTile(
                  title: Text(
                    '${files.length} Duplicate Files',
                  ),
                  children: files.map((path) {
                    return ListTile(
                      title: Text(
                        path.split(RegExp(r'[\\/]')).last,
                      ),
                      subtitle: Text(path),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Favorites',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            FutureBuilder<List<String>>(
              future: AdvancedFavorites.getFavorites(),
              builder: (context, snapshot) {
                final favorites = snapshot.data ?? [];

                if (favorites.isEmpty) {
                  return const Card(
                    child: ListTile(
                      title: Text('No favorites added'),
                    ),
                  );
                }

                return Column(
                  children: favorites.map((path) {
                    return ListTile(
                      leading: const Icon(Icons.star),
                      title: Text(
                        path.split(RegExp(r'[\\/]')).last,
                      ),
                      onTap: () => OpenFilex.open(path),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Recently Opened',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            FutureBuilder<List<String>>(
              future: AdvancedRecentFiles.getRecentFiles(),
              builder: (context, snapshot) {
                final recent = snapshot.data ?? [];

                if (recent.isEmpty) {
                  return const Card(
                    child: ListTile(
                      title: Text('No recent files'),
                    ),
                  );
                }

                return Column(
                  children: recent.map((path) {
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(
                        path.split(RegExp(r'[\\/]')).last,
                      ),
                      onTap: () => OpenFilex.open(path),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


















