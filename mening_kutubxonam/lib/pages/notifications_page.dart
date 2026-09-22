import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/user_firestore.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f7f8),
      appBar: AppBar(
        title: const Text(
          'Bildirishnomalar',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: userFirestore
            .collection('borrowed_books')
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.red),
            );
          }

          if (snapshot.hasError) {
            return const _EmptyNotifications(
              icon: Icons.error_outline_rounded,
              message: 'Bildirishnomalarni yuklab bo\'lmadi',
            );
          }

          final now = DateTime.now();
          final overdue = (snapshot.data?.docs ?? []).where((document) {
            final data = document.data() as Map<String, dynamic>;
            final dueDate = _readDate(data['end_date']);
            return dueDate != null && dueDate.isBefore(now);
          }).toList();

          overdue.sort((first, second) {
            final firstDate = _readDate(
              (first.data() as Map<String, dynamic>)['end_date'],
            );
            final secondDate = _readDate(
              (second.data() as Map<String, dynamic>)['end_date'],
            );
            return firstDate!.compareTo(secondDate!);
          });

          if (overdue.isEmpty) {
            return const _EmptyNotifications(
              icon: Icons.notifications_none_rounded,
              message: 'Hozircha muddati o\'tgan kitoblar yo\'q',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xfffff3f3),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xffffd5d5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xffc62828),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Qaytarilishi kechikkan kitoblar',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${overdue.length} ta kitob muddatidan o\'tgan',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ...overdue.map((document) {
                final data = document.data() as Map<String, dynamic>;
                return _OverdueBookCard(borrowDocId: document.id, data: data);
              }),
            ],
          );
        },
      ),
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class _OverdueBookCard extends StatelessWidget {
  const _OverdueBookCard({required this.borrowDocId, required this.data});

  final String borrowDocId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final studentName = (data['student_name'] ?? 'Noma\'lum o\'quvchi')
        .toString();
    final bookTitle = (data['book_title'] ?? 'Noma\'lum kitob').toString();
    final dueDate = (data['end_date'] as Timestamp).toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xffffe2e2),
                foregroundColor: const Color(0xffc62828),
                child: Text(
                  _initials(studentName),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'O\'quvchi',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xffffeeee),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Muddati o\'tgan',
                  style: TextStyle(
                    color: Color(0xffc62828),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.menu_book_rounded, color: Color(0xffc62828)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Olingan kitob',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bookTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.event_rounded, color: Colors.grey, size: 20),
              const SizedBox(width: 10),
              Text(
                'Topshirish sanasi: ${DateFormat('dd.MM.yyyy').format(dueDate)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showReceiveConfirmation(
                context,
                studentName,
                data['book_isbn']?.toString() ?? '',
              ),
              icon: const Icon(Icons.assignment_return_rounded, size: 19),
              label: const Text('Qabul qilish'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xffc62828),
                side: const BorderSide(color: Color(0xffc62828)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showReceiveConfirmation(
    BuildContext context,
    String studentName,
    String isbn,
  ) async {
    final shouldReceive = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            height: 98,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xffffeeee),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assignment_return_rounded,
                    color: Color(0xffc62828),
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
                  child: const Text(
                    'Bekor qilish',
                    style: TextStyle(color: Colors.black54),
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

    if (shouldReceive == true && context.mounted) {
      await _receiveBook(context, isbn);
    }
  }

  Future<void> _receiveBook(BuildContext context, String isbn) async {
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
        final bookData = book.data();
        final total = (bookData['count'] as num?)?.toInt() ?? 1;
        final available = (bookData['available_count'] as num?)?.toInt() ?? 0;
        await book.reference.update({
          'count': total,
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'IO';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
