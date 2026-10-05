import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';

import '../ui_helpers.dart';
import '../services/user_firestore.dart';

class ClassStudentsPage extends StatefulWidget {
  final String classId;
  final String className;

  const ClassStudentsPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ClassStudentsPage> createState() => _ClassStudentsPageState();
}

class _ClassStudentsPageState extends State<ClassStudentsPage> {
  String searchQuery = '';
  String currentFilter = 'A-Z';

  final List<String> filterOptions = ['A-Z', 'Z-A', 'Eng faol', 'No-faol'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.dividerColor.withValues(alpha: 0.3);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 1,
        title: Text(
          '${widget.className} o\'quvchilari',
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) {
                      setState(() {
                        searchQuery = val.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Qidirish (Ism familiya)...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: theme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
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
                  onPressed: _showFilterSheet,
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: theme.colorScheme.onSurface,
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
                onPressed: _showAddStudentModal,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'O\'quvchi qo\'shish',
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
            // Student Table
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: userFirestore
                    .collection('students')
                    .where('class_id', isEqualTo: widget.classId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.red),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text("Hozircha o'quvchilar yo'q."),
                    );
                  }

                  List<QueryDocumentSnapshot> docs = snapshot.data!.docs;

                  docs = docs.where((doc) {
                    Map<String, dynamic> data =
                        doc.data() as Map<String, dynamic>;
                    String name = (data['full_name'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(searchQuery);
                  }).toList();

                  docs.sort((a, b) {
                    String nameA =
                        (a.data() as Map<String, dynamic>)['full_name']
                            ?.toString()
                            .toLowerCase() ??
                        '';
                    String nameB =
                        (b.data() as Map<String, dynamic>)['full_name']
                            ?.toString()
                            .toLowerCase() ??
                        '';
                    if (currentFilter == 'Z-A') return nameB.compareTo(nameA);
                    return nameA.compareTo(nameB);
                  });

                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingTextStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        columns: const [
                          DataColumn(label: Text('T/R')),
                          DataColumn(label: Text('O\'quvchi ism familiyasi')),
                          DataColumn(label: Text('Harakat')),
                        ],
                        rows: List.generate(docs.length, (index) {
                          var data = docs[index].data() as Map<String, dynamic>;
                          String docId = docs[index].id;

                          return DataRow(
                            cells: [
                              DataCell(Text('${index + 1}')),
                              DataCell(Text(data['full_name'] ?? '')),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.history,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () => _showStudentHistory(
                                        docId,
                                        data['full_name'],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.book,
                                        color: Colors.green,
                                      ),
                                      onPressed: () => _showGiveBookModal(
                                        docId,
                                        data['full_name'],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _deleteStudent(docId),
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
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Olingan kitoblar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            // Borrowed books list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: userFirestore
                    .collection('borrowed_books')
                    .where('class_id', isEqualTo: widget.classId)
                    .where('status', isEqualTo: 'active')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.red),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text("Hozircha olingan kitoblar yo'q."),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      var data = doc.data() as Map<String, dynamic>;

                      DateTime startDate = (data['start_date'] as Timestamp)
                          .toDate();
                      DateTime endDate = (data['end_date'] as Timestamp)
                          .toDate();
                      String formattedStart = DateFormat('yyyy-MM-dd')
                          .format(startDate);
                      String formattedEnd = DateFormat('yyyy-MM-dd')
                          .format(endDate);

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(
                            data['book_title'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('O\'quvchi: ${data['student_name']}'),
                              Text(
                                'Berilgan: $formattedStart | Qaytarish: $formattedEnd',
                              ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _confirmReceiveBook(
                              doc.id,
                              data['book_isbn'],
                              data['student_name']?.toString() ?? 'o\'quvchi',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Qabul qilish',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
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

  void _showAddStudentModal() {
    final TextEditingController nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'O\'quvchi qo\'shish',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Ism va Familiya',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (isSaving) return;
                              final name = nameController.text.trim();
                              if (name.isEmpty) return;

                              isSaving = true;
                              setState(() {});

                              try {
                                await userFirestore.collection('students').add({
                                  'full_name': name,
                                  'class_id': widget.classId,
                                  'createdAt': FieldValue.serverTimestamp(),
                                });

                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Xatolik: $e (Firebase ruxsatnomasi (Rules) eskirgan bo\'lishi mumkin)',
                                      ),
                                    ),
                                  );
                                  setState(() => isSaving = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Qo\'shish',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _deleteStudent(String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tasdiqlash'),
        content: const Text('O\'quvchini o\'chirib yuborasizmi?'),
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
      await userFirestore.collection('students').doc(docId).delete();
    }
  }

  void _receiveBook(String borrowDocId, String isbn) async {
    await showLoading(context);
    try {
      await userFirestore.collection('borrowed_books').doc(borrowDocId).update({
        'status': 'returned',
        'returned_date': FieldValue.serverTimestamp(),
      });
      final books = await userFirestore
          .collection('books')
          .where('isbn', isEqualTo: isbn)
          .limit(1)
          .get();
      if (books.docs.isNotEmpty) {
        final book = books.docs.first;
        final data = book.data();
        final total = (data['count'] as num?)?.toInt() ?? 1;
        final available = (data['available_count'] as num?)?.toInt() ?? 0;
        await book.reference.update({
          'count': total,
          'available_count': (available + 1).clamp(0, total),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Xatolik: $e')));
      }
    }
  }

  Future<void> _confirmReceiveBook(
    String borrowDocId,
    String isbn,
    String studentName,
  ) async {
    final shouldReceive = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            height: 100,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
            decoration: BoxDecoration(
              color: Theme.of(sheetContext).cardColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.all(
                color: Theme.of(sheetContext).dividerColor
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext).brightness == Brightness.dark
                        ? const Color(0xff402326)
                        : const Color(0xffffeeee),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.assignment_return_rounded,
                    color: Theme.of(sheetContext).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$studentName kitobni qaytardimi?',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: Text(
                    'Bekor qilish',
                    style: TextStyle(
                      color: Theme.of(sheetContext)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffc62828),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: const Text('Qabul qilish'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldReceive == true && mounted) {
      _receiveBook(borrowDocId, isbn);
    }
  }

  void _showStudentHistory(String studentId, String studentName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                '$studentName tarixi',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: userFirestore
                      .collection('borrowed_books')
                      .where('student_id', isEqualTo: studentId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.red),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("Tarix mavjud emas."));
                    }

                    var docs = snapshot.data!.docs;

                    // Local sort by book_title to avoid complex index requirement
                    List<QueryDocumentSnapshot> sortedDocs = docs.toList();
                    sortedDocs.sort((a, b) {
                      String titleA =
                          (a.data() as Map<String, dynamic>)['book_title']
                              ?.toString()
                              .toLowerCase() ??
                          '';
                      String titleB =
                          (b.data() as Map<String, dynamic>)['book_title']
                              ?.toString()
                              .toLowerCase() ??
                          '';
                      return titleA.compareTo(titleB);
                    });

                    return ListView.builder(
                      itemCount: sortedDocs.length,
                      itemBuilder: (context, index) {
                        var data =
                            sortedDocs[index].data() as Map<String, dynamic>;

                        String status = data['status'] == 'returned'
                            ? 'Qaytarilgan'
                            : 'Olingan';
                        Color statusColor = data['status'] == 'returned'
                            ? Colors.green
                            : Colors.red;

                        DateTime startDate = (data['start_date'] as Timestamp)
                            .toDate();
                        String formattedStart = DateFormat('yyyy-MM-dd')
                            .format(startDate);
                        String formattedReturned = "-";

                        if (data['returned_date'] != null) {
                          DateTime returnedDate =
                              (data['returned_date'] as Timestamp).toDate();
                          formattedReturned = DateFormat('yyyy-MM-dd')
                              .format(returnedDate);
                        }

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(
                              data['book_title'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Berilgan: $formattedStart\nQaytarilgan: $formattedReturned',
                            ),
                            trailing: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () {
                              _showHistoryDetails(data);
                            },
                          ),
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

  void _showHistoryDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        DateTime startDate = (data['start_date'] as Timestamp).toDate();
        DateTime endDate = (data['end_date'] as Timestamp).toDate();
        String returned = "Qaytarilmagan";
        if (data['returned_date'] != null) {
          returned = DateFormat('yyyy-MM-dd HH:mm')
              .format((data['returned_date'] as Timestamp).toDate());
        }

        return AlertDialog(
          title: Text(
            data['book_title'],
            style: const TextStyle(color: Colors.red),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ISBN: ${data['book_isbn']}'),
              Text('O\'quvchi: ${data['student_name']}'),
              Text(
                'Berilgan sana: ${DateFormat('yyyy-MM-dd').format(startDate)}',
              ),
              Text(
                'Qaytarish muddati: ${DateFormat('yyyy-MM-dd').format(endDate)}',
              ),
              Text('Haqiqiy qaytarilgan sana: $returned'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Yopish',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGiveBookModal(String studentId, String studentName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return GiveBookModal(
          studentId: studentId,
          studentName: studentName,
          classId: widget.classId,
        );
      },
    );
  }
}

class GiveBookModal extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String classId;

  const GiveBookModal({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.classId,
  });

  @override
  State<GiveBookModal> createState() => _GiveBookModalState();
}

class _GiveBookModalState extends State<GiveBookModal> {
  bool _isScanning = true;
  MobileScannerController cameraController = MobileScannerController();

  String? bookIsbn;
  String? bookTitle;
  String? bookAuthor;
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _fetchBookDetails(String isbn) async {
    var query = await userFirestore
        .collection('books')
        .where('isbn', isEqualTo: isbn)
        .get();
    if (query.docs.isNotEmpty) {
      var data = query.docs.first.data();
      setState(() {
        bookIsbn = isbn;
        bookTitle = data['title'];
        bookAuthor = data['author'];
        _isScanning = false;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Kitob topilmadi!')));
      }
      setState(() {
        _isScanning = true;
      });
      cameraController.start();
    }
  }

  void _showDatePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 300,
          color: Theme.of(context).cardColor,
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: endDate,
                  onDateTimeChanged: (DateTime newDate) {
                    setState(() {
                      endDate = newDate;
                    });
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Tanlash',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _giveBook() async {
    if (bookIsbn == null || bookTitle == null) return;

    await showLoading(context);

    // Baza bo'yicha kitob qolganligini tekshirish
    var bookQuery = await userFirestore
        .collection('books')
        .where('isbn', isEqualTo: bookIsbn)
        .get();
    if (bookQuery.docs.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }

    int totalCount = bookQuery.docs.first.data()['count'] ?? 1;

    var activeBorrows = await userFirestore
        .collection('borrowed_books')
        .where('book_isbn', isEqualTo: bookIsbn)
        .where('status', isEqualTo: 'active')
        .get();

    final alreadyBorrowed = activeBorrows.docs.any((document) {
      final data = document.data();
      return data['student_id']?.toString() == widget.studentId;
    });

    if (alreadyBorrowed) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bu o\'quvchi ushbu kitobni hali qaytarmagan. '
              'Qaytargandan keyin yana olishi mumkin.',
            ),
          ),
        );
      }
      return;
    }

    int activeCount = activeBorrows.docs.length;

    if (activeCount >= totalCount) {
      if (mounted) {
        Navigator.pop(context); // Close loading overlay
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kutubxonada bu kitob qolmagan (Barcha nusxalari band qilingan)!',
            ),
          ),
        );
      }
      return;
    }

    try {
      await userFirestore.collection('borrowed_books').add({
        'book_isbn': bookIsbn,
        'book_title': bookTitle,
        'student_id': widget.studentId,
        'student_name': widget.studentName,
        'class_id': widget.classId,
        'start_date': Timestamp.fromDate(startDate),
        'end_date': Timestamp.fromDate(endDate),
        'returned_date': null,
        'status': 'active',
      });
      final book = bookQuery.docs.first;
      await book.reference.update({
        'count': totalCount,
        'available_count': (totalCount - activeCount - 1).clamp(0, totalCount),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Xatolik: $e')));
      }
      return;
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    double modalHeight = _isScanning ? 300 : 500;

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
          const Text(
            'Kitob berish',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (_isScanning)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final String? rawValue = barcodes.first.rawValue;
                      if (rawValue != null) {
                        cameraController.stop();
                        _fetchBookDetails(rawValue);
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: TextEditingController(text: bookTitle),
                      decoration: const InputDecoration(
                        labelText: 'Kitob nomi',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: TextEditingController(text: bookAuthor),
                      decoration: const InputDecoration(
                        labelText: 'Muallif',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: TextEditingController(text: bookIsbn),
                      decoration: const InputDecoration(
                        labelText: 'ISBN',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: TextEditingController(
                        text: DateFormat('yyyy-MM-dd').format(startDate),
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Boshlanish kuni',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _showDatePicker,
                      child: AbsorbPointer(
                        child: TextField(
                          controller: TextEditingController(
                            text: DateFormat('yyyy-MM-dd').format(endDate),
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Tugash kuni',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _giveBook,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Berish',
                          style: TextStyle(
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
