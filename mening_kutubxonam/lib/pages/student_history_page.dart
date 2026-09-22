import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/user_firestore.dart';

class StudentHistoryPage extends StatefulWidget {
  const StudentHistoryPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  final String studentId;
  final String studentName;

  @override
  State<StudentHistoryPage> createState() => _StudentHistoryPageState();
}

class _StudentHistoryPageState extends State<StudentHistoryPage> {
  int selectedTab = 0;
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f7f8),
      appBar: AppBar(
        leading: IconButton.filledTonal(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Ortga',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xfffff0f0),
            foregroundColor: const Color(0xffc62828),
          ),
        ),
        title: const Text(
          'Tarix',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: userFirestore
            .collection('borrowed_books')
            .where('student_id', isEqualTo: widget.studentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.red),
            );
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Tarixni yuklab bo\'lmadi'));
          }

          final documents = (snapshot.data?.docs ?? []).where((document) {
            final data = document.data() as Map<String, dynamic>;
            final isClosed =
                data['status'] == 'returned' || data['status'] == 'archived';
            final matchesTab = selectedTab == 0 ? isClosed : !isClosed;
            final title = (data['book_title'] ?? '').toString().toLowerCase();
            return matchesTab && title.contains(searchQuery);
          }).toList();

          documents.sort((first, second) {
            final firstDate = _dateFrom(
              (first.data() as Map<String, dynamic>)['start_date'],
            );
            final secondDate = _dateFrom(
              (second.data() as Map<String, dynamic>)['start_date'],
            );
            return secondDate.compareTo(firstDate);
          });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  children: [
                    _StudentHeader(name: widget.studentName),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (value) =>
                          setState(() => searchQuery = value.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Qidirish (kitob nomi)...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _HistoryTab(
                          label: 'Qabul qilingan',
                          icon: Icons.check_circle_outline_rounded,
                          selected: selectedTab == 0,
                          color: Colors.green,
                          onTap: () => setState(() => selectedTab = 0),
                        ),
                        const SizedBox(width: 8),
                        _HistoryTab(
                          label: 'Hali qaytarilmagan',
                          icon: Icons.autorenew_rounded,
                          selected: selectedTab == 1,
                          color: Colors.red,
                          onTap: () => setState(() => selectedTab = 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: documents.isEmpty
                    ? Center(
                        child: Text(
                          selectedTab == 0
                              ? 'Qabul qilingan kitoblar yo\'q'
                              : 'Hali qaytarilmagan kitoblar yo\'q',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: documents.length,
                        itemBuilder: (context, index) {
                          return _HistoryBookCard(
                            data:
                                documents[index].data() as Map<String, dynamic>,
                            onReceive: selectedTab == 1
                                ? () => _confirmReceive(
                                    documents[index].id,
                                    (documents[index].data()
                                                as Map<
                                                  String,
                                                  dynamic
                                                >)['book_isbn']
                                            ?.toString() ??
                                        '',
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  DateTime _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime(1970);
  }

  Future<void> _confirmReceive(String borrowId, String isbn) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          height: 100,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Row(
            children: [
              const Icon(Icons.assignment_return_rounded, color: Colors.red),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Kitobni qabul qilasizmi?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: const Text(
                  'Bekor qilish',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Qabul qilish'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await userFirestore.collection('borrowed_books').doc(borrowId).update({
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
          'available_count': (available + 1).clamp(0, total),
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Xatolik: $error')));
      }
    }
  }
}

class _StudentHeader extends StatelessWidget {
  const _StudentHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xffffe2e2),
          foregroundColor: const Color(0xffc62828),
          child: Text(
            _initials(name),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O\'quvchi',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              name,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const Text(
              'Barcha amallar tarixi',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return parts.first.isEmpty ? 'IO' : parts.first[0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? color : Colors.grey.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: selected ? Colors.white : color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryBookCard extends StatelessWidget {
  const _HistoryBookCard({required this.data, this.onReceive});

  final Map<String, dynamic> data;
  final VoidCallback? onReceive;

  @override
  Widget build(BuildContext context) {
    final returned =
        data['status'] == 'returned' || data['status'] == 'archived';
    final start = _dateFrom(data['start_date']);
    final due = _dateFrom(data['end_date']);
    final returnedDate = data['returned_date'] == null
        ? null
        : _dateFrom(data['returned_date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 56,
            decoration: BoxDecoration(
              color: returned
                  ? const Color(0xffe8f8ee)
                  : const Color(0xffffe8e8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              color: returned ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['book_title'] ?? 'Noma\'lum kitob').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Berilgan: ${DateFormat('dd.MM.yyyy').format(start)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  returnedDate == null
                      ? 'Topshirish: ${DateFormat('dd.MM.yyyy').format(due)}'
                      : data['status'] == 'archived'
                      ? 'Yil yakunida arxivlangan'
                      : 'Qabul qilingan: ${DateFormat('dd.MM.yyyy').format(returnedDate)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          if (onReceive != null)
            TextButton(
              onPressed: onReceive,
              child: const Text(
                'Qabul qilish',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            )
          else
            Icon(
              returned ? Icons.check_circle_rounded : Icons.schedule_rounded,
              color: returned ? Colors.green : Colors.red,
            ),
        ],
      ),
    );
  }

  DateTime _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime(1970);
  }
}
