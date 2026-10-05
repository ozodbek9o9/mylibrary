import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'class_students_page.dart';
import 'student_history_page.dart';
import 'borrowed_books_page.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton.filledTonal(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Ortga',
          style: IconButton.styleFrom(
            backgroundColor: isDark
                ? const Color(0xff342124)
                : const Color(0xfffff0f0),
            foregroundColor: isDark
                ? const Color(0xffff8a80)
                : const Color(0xffc62828),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.className} o\'quvchilari',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Barcha ro\'yxatdagi o\'quvchilar',
              style: TextStyle(
                fontSize: 11,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
        actions: [
          IconButton.filledTonal(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BorrowedBooksPage(classId: widget.classId),
              ),
            ),
            icon: const Icon(Icons.menu_book_rounded),
            tooltip: 'Olingan kitoblar',
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xff342124)
                  : const Color(0xfffff0f0),
              foregroundColor: isDark
                  ? const Color(0xffff8a80)
                  : const Color(0xffc62828),
            ),
          ),
          const SizedBox(width: 8),
        ],
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
                              prefixIcon: Icon(
                                Icons.search,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              filled: true,
                              fillColor: theme.cardColor,
                              border: _border(context),
                              enabledBorder: _border(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _showFilterSheet,
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: const Text('Filter'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? const Color(0xffff8a80)
                                : Colors.red,
                            minimumSize: const Size(90, 54),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.red.withValues(alpha: 0.35)
                                  : const Color(0xffffcaca),
                            ),
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

  OutlineInputBorder _border(BuildContext context) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(
      color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
    ),
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
        var isSaving = false;
        return StatefulBuilder(
          builder: (context, setModalState) => SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Material(
                color: Theme.of(context).cardColor,
                elevation: 18,
                shadowColor: Colors.black.withValues(alpha: 0.3),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 15, left: 12, right: 12),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                      bottom: Radius.circular(22),
                    ),
                    border: Border.all(
                      color: Theme.of(context).dividerColor
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'O\'quvchi qo\'shish',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.primary,
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
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (isSaving) return;
                                    final name = controller.text.trim();
                                    if (name.isEmpty) return;

                                    isSaving = true;
                                    setModalState(() {});
                                    try {
                                      await userFirestore
                                          .collection('students')
                                          .add({
                                            'full_name': name,
                                            'class_id': widget.classId,
                                            'createdAt':
                                                FieldValue.serverTimestamp(),
                                          });
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    } catch (error) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(
                                              content: Text('Xatolik: $error'),
                                            ),
                                          );
                                      setModalState(() => isSaving = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(42),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Qo\'shish',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actionColor = isDark ? color.withValues(alpha: 0.9) : color;

    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: actionColor.withValues(alpha: isDark ? 0.16 : 0.09),
        foregroundColor: actionColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, color: actionColor, size: 19),
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
    );
  }
}
