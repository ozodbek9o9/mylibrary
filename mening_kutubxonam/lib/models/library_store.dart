import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../services/user_firestore.dart';

class Book {
  Book({
    required this.isbn,
    required this.name,
    required this.author,
    required this.genre,
    required this.quantity,
    this.borrowedBy,
  });
  String isbn, name, author, genre;
  int quantity;
  String? borrowedBy;
  bool get available => quantity > 0 && borrowedBy == null;
  Map<String, dynamic> toMap() => {
    'isbn': isbn,
    'name': name,
    'author': author.isEmpty ? '-' : author,
    'genre': genre,
    'quantity': quantity,
    'borrowedBy': borrowedBy,
  };
  factory Book.fromMap(Map<String, dynamic> map) => Book(
    isbn: '${map['isbn']}',
    name: '${map['name']}',
    author: '${map['author'] ?? '-'}',
    genre: '${map['genre']}',
    quantity: (map['quantity'] as num?)?.toInt() ?? 0,
    borrowedBy: map['borrowedBy'] as String?,
  );
}

class HistoryEntry {
  HistoryEntry({
    required this.id,
    required this.bookName,
    required this.isbn,
    required this.borrowedAt,
    required this.dueAt,
    this.returnedAt,
  });
  final String id, bookName, isbn;
  final DateTime borrowedAt, dueAt;
  DateTime? returnedAt;
  Map<String, dynamic> toMap() => {
    'bookName': bookName,
    'isbn': isbn,
    'borrowedAt': Timestamp.fromDate(borrowedAt),
    'dueAt': Timestamp.fromDate(dueAt),
    'returnedAt': returnedAt == null ? null : Timestamp.fromDate(returnedAt!),
  };
  factory HistoryEntry.fromMap(String id, Map<String, dynamic> map) =>
      HistoryEntry(
        id: id,
        bookName: '${map['bookName']}',
        isbn: '${map['isbn']}',
        borrowedAt: (map['borrowedAt'] as Timestamp).toDate(),
        dueAt: (map['dueAt'] as Timestamp).toDate(),
        returnedAt: (map['returnedAt'] as Timestamp?)?.toDate(),
      );
}

class Student {
  Student(this.name, {this.id});
  String name;
  String? id;
  final List<HistoryEntry> history = [];
  int get readCount => history.length;
}

class LibraryStore extends ChangeNotifier {
  final books = <Book>[];
  final classes = <String, List<Student>>{};
  bool loading = false;

  Future<void> load() async {
    try {
      loading = true;
      final bookSnapshot = await userFirestore.collection('books').get();
      final classSnapshot = await userFirestore.collection('classes').get();
      books
        ..clear()
        ..addAll(bookSnapshot.docs.map((doc) => Book.fromMap(doc.data())));
      classes.clear();
      for (final classDoc in classSnapshot.docs) {
        final studentSnapshot = await classDoc.reference
            .collection('students')
            .get();
        classes[classDoc.id] = studentSnapshot.docs
            .map(
              (doc) =>
                  Student(doc.data()['name'] as String? ?? '-', id: doc.id),
            )
            .toList();
        for (final studentDoc in studentSnapshot.docs) {
          final historySnapshot = await studentDoc.reference
              .collection('history')
              .get();
          final student = classes[classDoc.id]!.firstWhere(
            (item) => item.id == studentDoc.id,
          );
          student.history.addAll(
            historySnapshot.docs.map(
              (doc) => HistoryEntry.fromMap(doc.id, doc.data()),
            ),
          );
        }
      }
    } catch (_) {
      // Seed data remains available while Firebase is offline.
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> addBook(Book book) async {
    if (books.any((item) => item.isbn == book.isbn)) {
      throw StateError('duplicate-isbn');
    }
    books.add(book);
    await _bookRef(book).set(book.toMap());
    notifyListeners();
  }

  Future<void> updateBook(Book book) async {
    await _bookRef(book).set(book.toMap());
    notifyListeners();
  }

  Future<void> deleteBook(Book book) async {
    books.remove(book);
    await _bookRef(book).delete();
    notifyListeners();
  }

  Future<void> addClass(String name) async {
    final value = name.trim();
    if (value.isEmpty || classes.containsKey(value)) return;
    classes[value] = [];
    await userFirestore.collection('classes').doc(value).set({'name': value});
    notifyListeners();
  }

  Future<void> addStudent(String className, String name) async {
    final value = name.trim();
    if (value.isEmpty) return;
    final student = Student(value);
    final ref = userFirestore
        .collection('classes')
        .doc(className)
        .collection('students')
        .doc();
    student.id = ref.id;
    classes.putIfAbsent(className, () => []).add(student);
    await ref.set({'name': value, 'className': className});
    notifyListeners();
  }

  Future<void> deleteStudent(String className, Student student) async {
    classes[className]?.remove(student);
    if (student.id != null) await _studentRef(className, student).delete();
    notifyListeners();
  }

  Future<void> borrowBook(
    String className,
    Student student,
    Book book,
    DateTime dueAt,
  ) async {
    if (!book.available) throw StateError('book-unavailable');
    student.id ??= student.name.hashCode.toString();
    final now = DateTime.now();
    final historyRef = _studentRef(
      className,
      student,
    ).collection('history').doc();
    final entry = HistoryEntry(
      id: historyRef.id,
      bookName: book.name,
      isbn: book.isbn,
      borrowedAt: now,
      dueAt: dueAt,
    );
    book.borrowedBy = student.name;
    book.quantity -= 1;
    student.history.add(entry);
    final loanRef = userFirestore.collection('loans').doc();
    final batch = userFirestore.batch();
    batch.set(_bookRef(book), book.toMap());
    batch.set(loanRef, {
      'isbn': book.isbn,
      'bookName': book.name,
      'studentName': student.name,
      'className': className,
      'borrowedAt': Timestamp.fromDate(now),
      'dueAt': Timestamp.fromDate(dueAt),
      'returnedAt': null,
    });
    batch.set(historyRef, entry.toMap());
    await batch.commit();
    notifyListeners();
  }

  Future<void> returnBook(String className, Student student, Book book) async {
    final entry = student.history.lastWhere(
      (item) => item.isbn == book.isbn && item.returnedAt == null,
    );
    entry.returnedAt = DateTime.now();
    book.borrowedBy = null;
    book.quantity += 1;
    await _bookRef(book).set(book.toMap());
    await _studentRef(
      className,
      student,
    ).collection('history').doc(entry.id).set(entry.toMap());
    notifyListeners();
  }

  DocumentReference<Map<String, dynamic>> _bookRef(Book book) =>
      userFirestore.collection('books').doc(book.isbn);
  DocumentReference<Map<String, dynamic>> _studentRef(
    String className,
    Student student,
  ) => userFirestore
      .collection('classes')
      .doc(className)
      .collection('students')
      .doc(student.id ?? student.name.hashCode.toString());
}

final libraryStore = LibraryStore();
