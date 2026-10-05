import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'student_directory_page.dart';
import '../services/student_year_export_service.dart';
import '../services/user_firestore.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  Set<String> selectedClasses = {};
  Map<String, String> classNames = {}; // Store names for editing
  bool _isSelectionMode = false;
  bool _isExportingPdf = false;
  int _refreshKey = 0;

  Future<void> _refreshStudents() async {
    await userFirestore
        .collection('classes')
        .get(const GetOptions(source: Source.server));
    if (mounted) setState(() => _refreshKey++);
  }

  void _showAddClassModal(
    BuildContext context, {
    String? docId,
    String? initialName,
  }) {
    final TextEditingController nameController = TextEditingController(
      text: initialName ?? '',
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Sinf oynasini yopish',
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
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
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
                        bottom: Radius.circular(22),
                        top: Radius.circular(16),
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
                            docId == null
                                ? 'Sinf qo\'shish'
                                : 'Sinfni tahrirlash',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Sinf nomi (Masalan: 10-A)',
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
                                      final name = nameController.text.trim();
                                      if (name.isEmpty) return;

                                      isSaving = true;
                                      setState(() {});

                                      try {
                                        if (docId == null) {
                                          await userFirestore
                                              .collection('classes')
                                              .add({
                                                'name': name,
                                                'createdAt':
                                                    FieldValue.serverTimestamp(),
                                              });
                                        } else {
                                          await userFirestore
                                              .collection('classes')
                                              .doc(docId)
                                              .update({'name': name});

                                          if (mounted) {
                                            setState(
                                              () => selectedClasses.clear(),
                                            );
                                          }
                                        }

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
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
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(42),
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
                                  : Text(
                                      docId == null ? 'Qo\'shish' : 'Saqlash',
                                      style: const TextStyle(
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
            );
          },
        );
      },
    );
  }

  void _deleteSelectedClasses() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tasdiqlash'),
        content: const Text(
          'Tanlangan sinflar va ulardagi BARCHA o\'quvchilar butunlay o\'chirib yuboriladi. Tasdiqlaysizmi?',
        ),
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

    if (confirm == true) {
      // Show loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: CircularProgressIndicator(color: Colors.red)),
      );

      for (String classId in selectedClasses) {
        // Delete all students in class
        var studentsQuery = await userFirestore
            .collection('students')
            .where('class_id', isEqualTo: classId)
            .get();
        for (var doc in studentsQuery.docs) {
          await doc.reference.delete();
        }
        // Delete the class
        await userFirestore.collection('classes').doc(classId).delete();
      }

      if (mounted) Navigator.pop(context); // hide loading
      setState(() {
        selectedClasses.clear();
      });
    }
  }

  void _toggleClassSelection(String classId) {
    setState(() {
      _isSelectionMode = true;
      if (selectedClasses.contains(classId)) {
        selectedClasses.remove(classId);
      } else {
        selectedClasses.add(classId);
      }
      if (selectedClasses.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).cardColor;
    final border = Theme.of(context).dividerColor.withValues(alpha: 0.18);
    final muted = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _refreshStudents,
        color: Colors.red,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const _StudentsHero(),
                const SizedBox(height: 20),
                if (!_isSelectionMode && selectedClasses.isEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddClassModal(context),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Sinf qo\'shish',
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
                  )
                else
                  Row(
                    children: [
                      if (selectedClasses.length == 1)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              String classId = selectedClasses.first;
                              _showAddClassModal(
                                context,
                                docId: classId,
                                initialName: classNames[classId],
                              );
                            },
                            icon: const Icon(Icons.edit, color: Colors.white),
                            label: const Text(
                              'Tahrirlash',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      if (selectedClasses.length == 1)
                        const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _deleteSelectedClasses,
                          icon: const Icon(Icons.delete, color: Colors.white),
                          label: const Text(
                            'O\'chirish',
                            style: TextStyle(color: Colors.white),
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
                    ],
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      'Mening sinflarim',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _isExportingPdf ? null : _exportStudentsPdf,
                      icon: _isExportingPdf
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Yuklash'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Color(0xffffcaca)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  key: ValueKey(_refreshKey),
                  stream: userFirestore
                      .collection('classes')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.red),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: Center(child: Text("Hozircha sinflar yo'q.")),
                      );
                    }

                    final docs = [...snapshot.data!.docs]
                      ..sort((first, second) {
                        final firstName =
                            ((first.data() as Map<String, dynamic>)['name'] ??
                                    '')
                                .toString();
                        final secondName =
                            ((second.data() as Map<String, dynamic>)['name'] ??
                                    '')
                                .toString();
                        return _compareClassNames(firstName, secondName);
                      });

                    return Column(
                      children: docs.map((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        String classId = doc.id;
                        String className = data['name'] ?? '';
                        classNames[classId] = className;

                        bool isSelected = selectedClasses.contains(classId);

                        return StreamBuilder<QuerySnapshot>(
                          stream: userFirestore
                              .collection('students')
                              .where('class_id', isEqualTo: classId)
                              .snapshots(),
                          builder: (context, studentSnap) {
                            int studentCount = studentSnap.hasData
                                ? studentSnap.data!.docs.length
                                : 0;
                            return Card(
                              elevation: isSelected ? 4 : 2,
                              color: isSelected
                                  ? (isDark
                                        ? const Color(0xff2a1b1b)
                                        : Colors.red.shade50)
                                  : surface,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: isSelected
                                    ? const BorderSide(
                                        color: Colors.red,
                                        width: 2,
                                      )
                                    : BorderSide(color: border, width: 1),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? Colors.red.shade700
                                      : Colors.red,
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                        )
                                      : const Icon(
                                          Icons.class_,
                                          color: Colors.white,
                                        ),
                                ),
                                title: Text(
                                  className,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                subtitle: Text(
                                  'O\'quvchilar soni: $studentCount',
                                  style: TextStyle(color: muted),
                                ),
                                trailing: isSelected
                                    ? null
                                    : Icon(
                                        Icons.arrow_forward_ios,
                                        color: muted,
                                      ),
                                onLongPress: () =>
                                    _toggleClassSelection(classId),
                                onTap: () {
                                  if (_isSelectionMode ||
                                      selectedClasses.isNotEmpty) {
                                    _toggleClassSelection(classId);
                                    return;
                                  }

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          StudentDirectoryPage(
                                            classId: classId,
                                            className: className,
                                          ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportStudentsPdf() async {
    setState(() => _isExportingPdf = true);
    try {
      final savedPath = await StudentYearExportService.exportCurrentYear();
      if (mounted) {
        final message = savedPath != null
            ? 'PDF saqlandi: $savedPath'
            : 'PDF tayyorlandi. Endi yangi o\'quv yiliga o\'tishingiz mumkin.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF yaratishda xatolik: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  int _compareClassNames(String first, String second) {
    final firstInfo = _classSortInfo(first);
    final secondInfo = _classSortInfo(second);

    final gradeResult = firstInfo.$1.compareTo(secondInfo.$1);
    if (gradeResult != 0) return gradeResult;

    final sectionResult = firstInfo.$2.compareTo(secondInfo.$2);
    if (sectionResult != 0) return sectionResult;

    return first.toLowerCase().compareTo(second.toLowerCase());
  }

  (int, String) _classSortInfo(String name) {
    final numberMatch = RegExp(r'^\s*(\d+)').firstMatch(name);
    final grade = numberMatch == null
        ? 999999
        : int.tryParse(numberMatch.group(1)!) ?? 999999;
    final rest = numberMatch == null ? name : name.substring(numberMatch.end);
    final section = rest
        .toLowerCase()
        .replaceAll('sinf', '')
        .replaceAll(RegExp(r'[^a-z]'), '');
    return (grade, section);
  }
}

class _StudentsHero extends StatelessWidget {
  const _StudentsHero();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xff281b1d), Color(0xff382124)]
              : const [Color(0xfffff4f4), Color(0xffffdddd)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.red.withValues(alpha: 0.28)
              : const Color(0xffffd0d0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xff43282c)
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'O\'quvchilar bo\'limi',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xffffa0a0)
                          : const Color(0xffc62828),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Har bir sinfda\nkatta imkoniyatlar!',
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: isDark ? const Color(0xfff5e9e9) : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'O\'quvchilar va sinflarni bir joydan boshqaring.',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xffd0bfc1)
                        : Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xff43282c)
                  : Colors.white.withValues(alpha: 0.78),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.groups_rounded,
              color: isDark ? const Color(0xffff858b) : const Color(0xffef3340),
              size: 38,
            ),
          ),
        ],
      ),
    );
  }
}
