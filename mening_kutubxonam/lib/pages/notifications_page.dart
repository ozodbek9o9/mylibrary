import 'package:flutter/material.dart';

import '../models/library_store.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bildirishnomalar',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: AnimatedBuilder(
        animation: libraryStore,
        builder: (context, _) {
          final overdue = _overdueLoans();
          return overdue.isEmpty
              ? const Center(
                  child: Text('Hozircha muddati o‘tgan kitoblar yo‘q'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: overdue.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final loan = overdue[index];
                    return Card(
                      elevation: 0,
                      color: const Color(0xffffeeee),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xffc62828),
                          foregroundColor: Colors.white,
                          child: Icon(Icons.warning_amber_rounded),
                        ),
                        title: Text(
                          loan.student,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${loan.className} sinf\nKitob: ${loan.book}\nQaytarish muddati: ${loan.dueAt.toLocal().toString().split(' ').first}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
        },
      ),
    );
  }

  List<_OverdueLoan> _overdueLoans() {
    final result = <_OverdueLoan>[];
    final now = DateTime.now();
    for (final entry in libraryStore.classes.entries) {
      for (final student in entry.value) {
        for (final history in student.history) {
          if (history.returnedAt == null && history.dueAt.isBefore(now)) {
            result.add(
              _OverdueLoan(
                className: entry.key,
                student: student.name,
                book: history.bookName,
                dueAt: history.dueAt,
              ),
            );
          }
        }
      }
    }
    return result;
  }
}

class _OverdueLoan {
  const _OverdueLoan({
    required this.className,
    required this.student,
    required this.book,
    required this.dueAt,
  });
  final String className, student, book;
  final DateTime dueAt;
}
