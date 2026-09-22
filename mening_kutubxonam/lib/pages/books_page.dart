import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../ui_helpers.dart';
import '../services/user_firestore.dart';

class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  String searchQuery = '';
  String currentFilter = 'A-Z'; // Default filter
  int _refreshKey = 0;

  final List<String> filterOptions = [
    'A-Z',
    'Z-A',
    'Sheriy kitoblar',
    'Badiiy kitoblar',
    'Ertak kitoblar',
    'Ilmiy kitoblar',
  ];

  Future<void> _refreshBooks() async {
    await userFirestore
        .collection('books')
        .get(const GetOptions(source: Source.server));
    if (mounted) setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Kitoblar',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Kutubxonadagi barcha kitoblar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),
            // Top action bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) {
                      setState(() {
                        searchQuery = val.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Qidirish (Nomi yoki ISBN)...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showFilterSheet(),
                  icon: const Icon(Icons.filter_list, color: Colors.white),
                  label: const Text(
                    'Filter',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showAddOrEditBookModal(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Kitob qo\'shish',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: RefreshIndicator(
                  onRefresh: _refreshBooks,
                  color: Colors.red,
                  child: StreamBuilder<QuerySnapshot>(
                    key: ValueKey(_refreshKey),
                    stream: userFirestore.collection('books').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.red),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 180),
                            Center(child: Text("Hozircha kitoblar yo'q.")),
                          ],
                        );
                      }

                      List<QueryDocumentSnapshot> docs = snapshot.data!.docs;

                      // Filtering & Searching
                      docs = docs.where((doc) {
                        Map<String, dynamic> data =
                            doc.data() as Map<String, dynamic>;
                        String title = (data['title'] ?? '')
                            .toString()
                            .toLowerCase();
                        String isbn = (data['isbn'] ?? '')
                            .toString()
                            .toLowerCase();
                        String genre = (data['genre'] ?? '');

                        bool matchesSearch =
                            title.contains(searchQuery) ||
                            isbn.contains(searchQuery);
                        bool matchesFilter = true;

                        if (currentFilter != 'A-Z' && currentFilter != 'Z-A') {
                          matchesFilter = genre == currentFilter;
                        }

                        return matchesSearch && matchesFilter;
                      }).toList();

                      // Sorting
                      docs.sort((a, b) {
                        String titleA =
                            (a.data() as Map<String, dynamic>)['title']
                                ?.toString()
                                .toLowerCase() ??
                            '';
                        String titleB =
                            (b.data() as Map<String, dynamic>)['title']
                                ?.toString()
                                .toLowerCase() ??
                            '';
                        if (currentFilter == 'Z-A') {
                          return titleB.compareTo(titleA);
                        }
                        return titleA.compareTo(titleB); // Default A-Z
                      });

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: DataTable(
                            headingTextStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            columns: const [
                              DataColumn(label: Text('T/R')),
                              DataColumn(label: Text('Kitob nomi')),
                              DataColumn(label: Text('Muallifi')),
                              DataColumn(label: Text('Janr')),
                              DataColumn(label: Text('Harakat')),
                            ],
                            rows: List.generate(docs.length, (index) {
                              var data =
                                  docs[index].data() as Map<String, dynamic>;
                              String docId = docs[index].id;
                              String author =
                                  (data['author'] == null ||
                                      data['author'].toString().trim().isEmpty)
                                  ? "-"
                                  : data['author'];

                              return DataRow(
                                cells: [
                                  DataCell(Text('${index + 1}')),
                                  DataCell(Text(data['title'] ?? '')),
                                  DataCell(Text(author)),
                                  DataCell(Text(data['genre'] ?? '')),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Bandlik holati',
                                          icon: const Icon(
                                            Icons.info_outline_rounded,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => _showBookBorrowers(
                                            data['isbn'],
                                            data['title'],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () =>
                                              _showAddOrEditBookModal(
                                                docId: docId,
                                                existingData: data,
                                              ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => _deleteBook(docId),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: filterOptions.map((filter) {
              return ListTile(
                title: Text(
                  filter,
                  style: TextStyle(
                    fontWeight: currentFilter == filter
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: currentFilter == filter
                    ? const Icon(Icons.check, color: Colors.red)
                    : null,
                onTap: () {
                  setState(() {
                    currentFilter = filter;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showAddOrEditBookModal({
    String? docId,
    Map<String, dynamic>? existingData,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return AddBookModal(docId: docId, existingData: existingData);
      },
    );
  }

  void _deleteBook(String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('O\'chirishni tasdiqlaysizmi?'),
        content: const Text('Bu kitob butunlay o\'chirib yuboriladi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Bekor qilish',
              style: TextStyle(color: Colors.black),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'O\'chirish',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm) {
      await userFirestore.collection('books').doc(docId).delete();
    }
  }

  void _showBookBorrowers(String isbn, String title) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: 270,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: userFirestore
                      .collection('borrowed_books')
                      .where('book_isbn', isEqualTo: isbn)
                      .where('status', isEqualTo: 'active')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.red),
                      );
                    }
                    var docs = snapshot.data!.docs;
                    return FutureBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      future: userFirestore
                          .collection('books')
                          .where('isbn', isEqualTo: isbn)
                          .limit(1)
                          .get()
                          .then((result) => result.docs.first),
                      builder: (context, bookSnapshot) {
                        final bookData = bookSnapshot.data?.data() ?? {};
                        final total = (bookData['count'] as num?)?.toInt() ?? 1;
                        final available =
                            (bookData['available_count'] as num?)?.toInt() ??
                            total - docs.length;
                        final status = docs.isEmpty
                            ? 'Kitob band emas'
                            : available <= 0
                            ? total == 1
                                  ? 'Kitob band'
                                  : 'Barcha kitoblar band'
                            : 'Jami: $total ta | Band: ${docs.length} ta | Qolgan: $available ta';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.builder(
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  final data =
                                      docs[index].data()
                                          as Map<String, dynamic>;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.person,
                                      color: Colors.red,
                                    ),
                                    title: Text(
                                      "Olingan: ${data['student_name']}",
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AddBookModal extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? existingData;

  const AddBookModal({super.key, this.docId, this.existingData});

  @override
  State<AddBookModal> createState() => _AddBookModalState();
}

class _AddBookModalState extends State<AddBookModal> {
  bool _isScanIntro = true;
  bool _isScanning = false;
  bool _hasMultipleCopies = false;
  MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  final TextEditingController _isbnController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _countController = TextEditingController(
    text: '1',
  );
  String _selectedGenre = 'Badiiy kitoblar';

  final List<String> genres = [
    'Badiiy kitoblar',
    'Sheriy kitoblar',
    'Ilmiy kitoblar',
    'Ertak kitoblar',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _isScanIntro = false;
      _isScanning = false; // Skip scan for editing
      _isbnController.text = widget.existingData!['isbn'] ?? '';
      _titleController.text = widget.existingData!['title'] ?? '';
      _authorController.text = widget.existingData!['author'] ?? '';
      final count = (widget.existingData!['count'] as num?)?.toInt() ?? 1;
      _hasMultipleCopies = count > 1;
      _countController.text = '$count';
      if (genres.contains(widget.existingData!['genre'])) {
        _selectedGenre = widget.existingData!['genre'];
      }
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    _isbnController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _countController.dispose();
    super.dispose();
  }

  void _saveBook() async {
    if (_isbnController.text.isEmpty || _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Iltimos, barcha majburiy maydonlarni to\'ldiring!'),
        ),
      );
      return;
    }

    // Check for duplicate ISBN if adding new
    if (widget.docId == null) {
      var existing = await userFirestore
          .collection('books')
          .where('isbn', isEqualTo: _isbnController.text.trim())
          .get();
      if (existing.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ushbu ISBN ga ega kitob allaqachon mavjud!'),
            ),
          );
        }
        return;
      }
    }

    Map<String, dynamic> bookData = {
      'isbn': _isbnController.text.trim(),
      'title': _titleController.text.trim(),
      'author': _authorController.text.trim(),
      'genre': _selectedGenre,
      'createdAt': FieldValue.serverTimestamp(),
    };
    final count = _hasMultipleCopies
        ? int.tryParse(_countController.text.trim()) ?? 0
        : 1;
    if (count < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kitob soni kamida 1 bo\'lishi kerak.')),
      );
      return;
    }
    bookData['count'] = count;
    if (widget.docId == null) {
      bookData['available_count'] = count;
    } else {
      final oldCount = (widget.existingData?['count'] as num?)?.toInt() ?? 1;
      final oldAvailable =
          (widget.existingData?['available_count'] as num?)?.toInt() ??
          oldCount;
      final borrowed = oldCount - oldAvailable;
      if (count < borrowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kamida $borrowed ta nusxa bo\'lishi kerak.')),
        );
        return;
      }
      bookData['available_count'] = count - borrowed;
    }

    if (mounted) await showLoading(context);

    try {
      if (widget.docId != null) {
        await userFirestore
            .collection('books')
            .doc(widget.docId)
            .update(bookData);
      } else {
        await userFirestore.collection('books').add(bookData);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Xatolik yuz berdi: $e (Ehtimol Firebase ruxsatnomalari (Rules) eskirgan)',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double modalHeight = _isScanIntro
        ? 200
        : (_isScanning ? 350 : screenHeight * 0.7);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: modalHeight,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.docId == null ? 'Kitob qo\'shish' : 'Kitobni tahrirlash',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_isScanIntro)
            Expanded(
              child: Center(
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isScanIntro = false;
                        _isScanning = true;
                      });
                    },
                    icon: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white,
                      size: 28,
                    ),
                    label: const Text(
                      'Kitobni skanerlash',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if (_isScanning)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final String? rawValue = barcodes.first.rawValue;
                      if (rawValue != null && rawValue.isNotEmpty) {
                        setState(() {
                          _isbnController.text = rawValue;
                          _isScanning = false;
                        });
                        cameraController.stop();
                      }
                    }
                  },
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: _isbnController,
                      decoration: const InputDecoration(
                        labelText: 'ISBN *',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Kitob nomi *',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _authorController,
                      decoration: const InputDecoration(
                        labelText: 'Muallifi',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedGenre,
                      decoration: const InputDecoration(
                        labelText: 'Janr',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                      ),
                      items: genres.map((String genre) {
                        return DropdownMenuItem<String>(
                          value: genre,
                          child: Text(genre),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedGenre = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _hasMultipleCopies,
                      title: const Text('1 tadan ko\'p bo\'lsa'),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) {
                        setState(() => _hasMultipleCopies = value ?? false);
                      },
                    ),
                    if (_hasMultipleCopies) ...[
                      const SizedBox(height: 4),
                      TextField(
                        controller: _countController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Kitoblar soni',
                          prefixIcon: Icon(Icons.numbers_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveBook,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.docId == null ? 'Qo\'shish' : 'Saqlash',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
