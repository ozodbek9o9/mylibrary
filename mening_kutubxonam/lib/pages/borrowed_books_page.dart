import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/user_firestore.dart';

class BorrowedBooksPage extends StatelessWidget {
  const BorrowedBooksPage({super.key, required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f7f8),
      appBar: AppBar(
        title: const Text(
          'Olingan kitoblar',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: userFirestore
            .collection('borrowed_books')
            .where('class_id', isEqualTo: classId)
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.red),
            );
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Kitoblarni yuklab bo\'lmadi'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Hozircha olingan kitoblar yo\'q'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _BorrowedBookCard(
                data: data,
                onReceive: () => _confirmReceive(
                  context,
                  docs[index].id,
                  data['book_isbn']?.toString() ?? '',
                  data['student_name']?.toString() ?? 'o\'quvchi',
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmReceive(
    BuildContext context,
    String borrowId,
    String isbn,
    String studentName,
  ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ReceiveSheet(studentName: studentName),
    );
    if (confirmed == true && context.mounted) {
      await _receiveBook(context, borrowId, isbn);
    }
  }

  Future<void> _receiveBook(
    BuildContext context,
    String borrowId,
    String isbn,
  ) async {
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
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Xatolik: $error')));
      }
    }
  }
}

class _BorrowedBookCard extends StatelessWidget {
  const _BorrowedBookCard({required this.data, required this.onReceive});

  final Map<String, dynamic> data;
  final VoidCallback onReceive;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xffffe8e8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.menu_book_rounded, color: Colors.red),
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
                const SizedBox(height: 5),
                Text(
                  (data['student_name'] ?? 'Noma\'lum o\'quvchi').toString(),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onReceive,
            child: const Text(
              'Qabul qilish',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiveSheet extends StatelessWidget {
  const _ReceiveSheet({required this.studentName});

  final String studentName;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
            Expanded(
              child: Text(
                '$studentName kitobni qaytardimi?',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Bekor qilish',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Qabul qilish'),
            ),
          ],
        ),
      ),
    );
  }
}
