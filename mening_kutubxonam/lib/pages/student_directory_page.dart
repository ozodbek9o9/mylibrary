import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'class_students_page.dart';
import 'student_history_page.dart';
import '../services/user_firestore.dart';

class StudentDirectoryPage extends StatefulWidget {
  const StudentDirectoryPage({
    super.key,
    required this.classId,
    required this.className,
  });

  final String classId;
  final String className;

  @override
  State<StudentDirectoryPage> createState() => _StudentDirectoryPageState();
}

class _StudentDirectoryPageState extends State<StudentDirectoryPage> {
  String searchQuery = '';
  String selectedFilter = 'Barchasi';

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.className} o\'quvchilari',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const Text(
              'Barcha ro\'yxatdagi o\'quvchilar',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
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
          if (snapshot.hasError) {
            return const Center(child: Text('O\'quvchilarni yuklab bo\'lmadi'));
          }

          final students = (snapshot.data?.docs ?? []).where((document) {
            final data = document.data() as Map<String, dynamic>;
            return (data['full_name'] ?? '').toString().toLowerCase().contains(
              searchQuery,
            );
          }).toList();
          students.sort((a, b) {
            final first = _name(a).toLowerCase();
            final second = _name(b).toLowerCase();
            return selectedFilter == 'Z-A'
                ? second.compareTo(first)
                : first.compareTo(second);
          });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (value) => setState(
                              () => searchQuery = value.toLowerCase(),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Qidirish (ism familiya)...',
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.grey,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: _border(),
                              enabledBorder: _border(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _showFilterSheet,
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: const Text('Filter'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            minimumSize: const Size(90, 54),
                            side: const BorderSide(color: Color(0xffffcaca)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showAddStudentModal,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('O\'quvchi qo\'shish'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: students.isEmpty
                    ? const Center(child: Text('Hozircha o\'quvchilar yo\'q'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: students.length,
                        itemBuilder: (context, index) => _StudentCard(
                          data: students[index].data() as Map<String, dynamic>,
                          id: students[index].id,
                          onHistory: () => _openHistory(
                            students[index].id,
                            _name(students[index]),
                          ),
                          onGiveBook: () => _openGiveBook(
                            students[index].id,
                            _name(students[index]),
                          ),
                          onDelete: () => _deleteStudent(students[index].id),
                        ),
                      ),
              ),
              _BorrowedBooksSection(
                classId: widget.classId,
                onReceive: _receiveBook,
              ),
            ],
          );
        },
      ),
    );
  }

  String _name(QueryDocumentSnapshot document) {
    return ((document.data() as Map<String, dynamic>)['full_name'] ?? '')
        .toString();
  }

  OutlineInputBorder _border() => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: Colors.grey.shade200),
  );

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Barchasi', 'A-Z', 'Z-A']
              .map(
                (filter) => ListTile(
                  title: Text(filter),
                  trailing: selectedFilter == filter
                      ? const Icon(Icons.check, color: Colors.red)
                      : null,
                  onTap: () {
                    setState(() => selectedFilter = filter);
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _showAddStudentModal() {
    final controller = TextEditingController();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'O\'quvchi oynasini yopish',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);
        return SlideTransition(position: offset, child: child);
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                height: 200,
                width: double.infinity,
                margin: const EdgeInsets.only(top: 15, left: 12, right: 12),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                    bottom: Radius.circular(22),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'O\'quvchi qo\'shish',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Ism va familiya',
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (controller.text.trim().isEmpty) return;
                            await userFirestore.collection('students').add({
                              'full_name': controller.text.trim(),
                              'class_id': widget.classId,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                            if (context.mounted) Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Qo\'shish',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openHistory(String id, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentHistoryPage(studentId: id, studentName: name),
      ),
    );
  }

  void _openGiveBook(String id, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => GiveBookModal(
        studentId: id,
        studentName: name,
        classId: widget.classId,
      ),
    );
  }

  Future<void> _deleteStudent(String id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('O\'chirishni tasdiqlaysizmi?'),
        content: const Text('O\'quvchi ro\'yxatdan o\'chiriladi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bekor qilish'),
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
    if (shouldDelete == true) {
      await userFirestore.collection('students').doc(id).delete();
    }
  }

  Future<void> _receiveBook(String id) async {
    await userFirestore.collection('borrowed_books').doc(id).update({
      'status': 'returned',
      'returned_date': FieldValue.serverTimestamp(),
    });
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.data,
    required this.id,
    required this.onHistory,
    required this.onGiveBook,
    required this.onDelete,
  });

  final Map<String, dynamic> data;
  final String id;
  final VoidCallback onHistory;
  final VoidCallback onGiveBook;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = (data['full_name'] ?? 'Noma\'lum').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _color(name),
            foregroundColor: Colors.white,
            child: Text(
              _initials(name),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          _IconAction(
            icon: Icons.history_rounded,
            color: Colors.blue,
            tooltip: 'Tarix',
            onTap: onHistory,
          ),
          _IconAction(
            icon: Icons.menu_book_rounded,
            color: Colors.red,
            tooltip: 'Kitob berish',
            onTap: onGiveBook,
          ),
          _IconAction(
            icon: Icons.delete_outline_rounded,
            color: Colors.red,
            tooltip: 'O\'chirish',
            onTap: onDelete,
          ),
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return parts.first.isEmpty ? 'IO' : parts.first[0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Color _color(String value) {
    const colors = [
      Color(0xffc62828),
      Color(0xff7b3fc6),
      Color(0xff008f8c),
      Color(0xffed7b25),
    ];
    return colors[value.length % colors.length];
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, color: color, size: 20),
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
    );
  }
}

class _BorrowedBooksSection extends StatelessWidget {
  const _BorrowedBooksSection({required this.classId, required this.onReceive});
  final String classId;
  final Future<void> Function(String id) onReceive;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: userFirestore
          .collection('borrowed_books')
          .where('class_id', isEqualTo: classId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return Container(
          constraints: const BoxConstraints(maxHeight: 230),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: const BoxDecoration(color: Color(0xfff7f7f8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Olingan kitoblar',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    '${docs.length}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: docs.isEmpty
                    ? const Center(
                        child: Text(
                          'Hozircha olingan kitoblar yo\'q',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.menu_book_outlined,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (data['book_title'] ?? '').toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        (data['student_name'] ?? '').toString(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => onReceive(doc.id),
                                  child: const Text(
                                    'Qabul qilish',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
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
        );
      },
    );
  }
}
