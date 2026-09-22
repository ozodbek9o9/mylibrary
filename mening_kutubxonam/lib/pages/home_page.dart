import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/user_firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Stats
  int totalBooks = 0;
  String mostReadBook = '-';
  int totalStudents = 0;
  int borrowedBooksCount = 0;

  List<String> topStudentFullNames = [];
  List<double> topStudentValues = [];
  bool _isLoading = true;

  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _booksSubscription;
  StreamSubscription<QuerySnapshot>? _studentsSubscription;
  StreamSubscription<QuerySnapshot>? _borrowedSubscription;

  // Latest data holders
  List<QueryDocumentSnapshot> _latestBooks = [];
  List<QueryDocumentSnapshot> _latestStudents = [];
  List<QueryDocumentSnapshot> _latestBorrowed = [];

  @override
  void initState() {
    super.initState();
    _listenToStreams();
  }

  void _listenToStreams() {
    _booksSubscription = userFirestore.collection('books').snapshots().listen((
      snap,
    ) {
      _latestBooks = snap.docs;
      _recomputeStats();
    });

    _studentsSubscription = userFirestore
        .collection('students')
        .snapshots()
        .listen((snap) {
          _latestStudents = snap.docs;
          _recomputeStats();
        });

    _borrowedSubscription = userFirestore
        .collection('borrowed_books')
        .snapshots()
        .listen((snap) {
          _latestBorrowed = snap.docs;
          _recomputeStats();
        });
  }

  void _recomputeStats() {
    int tempTotalBooks = _latestBooks.length;
    int tempTotalStudents = _latestStudents.length;

    Map<String, int> bookReads = {};
    Map<String, int> studentMonthlyReads = {};
    Map<String, String> studentIdToFullName = {};
    int tempBorrowedCount = 0;

    DateTime now = DateTime.now();

    for (var doc in _latestBorrowed) {
      final data = doc.data() as Map<String, dynamic>;
      final String title = data['book_title'] ?? 'Noma\'lum';
      final String studentName = data['student_name'] ?? 'Noma\'lum';
      final String studentId = data['student_id'] ?? '';
      final String status = data['status'] ?? '';
      final Timestamp? startDate = data['start_date'];

      // Overall reads for "most read book"
      bookReads[title] = (bookReads[title] ?? 0) + 1;

      if (studentId.isNotEmpty) {
        studentIdToFullName[studentId] = studentName;
        // Monthly reads for bar chart
        if (startDate != null) {
          final DateTime dt = startDate.toDate();
          if (dt.year == now.year && dt.month == now.month) {
            studentMonthlyReads[studentId] =
                (studentMonthlyReads[studentId] ?? 0) + 1;
          }
        }
      }

      if (status == 'active') tempBorrowedCount++;
    }

    // Find most read book
    String tempMostRead = '-';
    int maxReads = 0;
    bookReads.forEach((title, cnt) {
      if (cnt > maxReads) {
        maxReads = cnt;
        tempMostRead = title;
      }
    });

    // Sort top students by monthly reads
    final sortedStudents = studentMonthlyReads.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top10 = sortedStudents.take(10).toList();
    final List<String> tempTopFullNames = top10
        .map((e) => studentIdToFullName[e.key] ?? '')
        .toList();
    final List<double> tempTopValues = top10
        .map((e) => e.value.toDouble())
        .toList();

    if (mounted) {
      setState(() {
        totalBooks = tempTotalBooks;
        totalStudents = tempTotalStudents;
        mostReadBook = tempMostRead;
        borrowedBooksCount = tempBorrowedCount;
        topStudentFullNames = tempTopFullNames;
        topStudentValues = tempTopValues;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _booksSubscription?.cancel();
    _studentsSubscription?.cancel();
    _borrowedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    }

    final stats = [
      (
        'Jami kitoblar',
        '$totalBooks',
        Icons.menu_book_rounded,
        const Color(0xffc62828),
      ),
      (
        'Ko\'p o\'qilayotgan',
        mostReadBook,
        Icons.local_fire_department_rounded,
        const Color(0xffe56b2f),
      ),
      (
        'Jami o\'quvchilar',
        '$totalStudents',
        Icons.groups_rounded,
        const Color(0xff187b8f),
      ),
      (
        'Berilgan kitoblar',
        '$borrowedBooksCount',
        Icons.assignment_return_rounded,
        const Color(0xff7355a5),
      ),
    ];

    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 300));
      },
      color: Colors.red,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        children: [
          const Text(
            'Xush kelibsiz!',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Kutubxona holati — avtomatik yangilanadi',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stats.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            itemBuilder: (_, i) {
              final stat = stats[i];
              return Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xffeeeeee)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(stat.$3, color: stat.$4, size: 25),
                    Text(
                      stat.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      stat.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          if (topStudentFullNames.isNotEmpty)
            _ReadersChart(
              fullNames: topStudentFullNames,
              values: topStudentValues,
            )
          else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xffeeeeee)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.bar_chart, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text(
                    'Eng faol o\'quvchilar',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bu oy hali hech kimga kitob berilmagan',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReadersChart extends StatelessWidget {
  const _ReadersChart({required this.fullNames, required this.values});
  final List<String> fullNames;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    double maxValue = 1;
    for (var v in values) {
      if (v > maxValue) maxValue = v;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffeeeeee)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Eng faol o\'quvchilar',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 3),
          const Text(
            'Joriy oy hisoboti — Top 10',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                fullNames.length,
                (i) => Expanded(child: _bar(context, i, maxValue)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, int index, double maxValue) {
    final double heightRatio = values[index] == 0
        ? 0
        : (values[index] / maxValue);
    final double barHeight = (heightRatio * 120).clamp(4.0, 120.0);
    final double colorIntensity = heightRatio.clamp(0.15, 1.0);
    final Color barColor = Color.lerp(
      const Color(0xffffd6d6),
      const Color(0xffc62828),
      colorIntensity,
    )!;

    return GestureDetector(
      onTap: () =>
          _showStudent(context, fullNames[index], values[index].round()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '${values[index].round()}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                  bottom: Radius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudent(BuildContext context, String fullName, int totalBooks) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        height: 120,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              fullName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.red,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.menu_book, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Bu oy o\'qilgan kitoblar: ',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                ),
                Text(
                  '$totalBooks ta',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
