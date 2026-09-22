import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'user_firestore.dart';

class StudentYearExportService {
  static final _dateFormat = DateFormat('dd.MM.yyyy');

  static Future<String?> exportCurrentYear() async {
    final firestore = userFirestore;
    final classesSnapshot = await firestore.collection('classes').get();
    final studentsSnapshot = await firestore.collection('students').get();
    final loansSnapshot = await firestore.collection('borrowed_books').get();

    // ── Unicode fontlarini yuklash ──────────────────────────────────────────
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final studentsByClass = <String, List<Map<String, dynamic>>>{};
    for (final document in studentsSnapshot.docs) {
      final data = document.data();
      studentsByClass
          .putIfAbsent(data['class_id']?.toString() ?? '', () => [])
          .add({...data, 'id': document.id});
    }

    final loansByStudent = <String, List<Map<String, dynamic>>>{};
    for (final document in loansSnapshot.docs) {
      final data = document.data();
      loansByStudent
          .putIfAbsent(data['student_id']?.toString() ?? '', () => [])
          .add(data);
    }

    final document = pw.Document();
    final red = PdfColor.fromHex('#C62828');
    final lightRed = PdfColor.fromHex('#FFF0F0');
    final now = DateTime.now();

    // Barcha sahifaga default font sifatida o'rnatamiz
    final theme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);

    document.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: red, width: 1.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Mening Kutubxonam',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: red,
                ),
              ),
              pw.Text(
                "O'quvchilar yillik hisoboti",
                style: pw.TextStyle(font: regularFont, fontSize: 10),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Sahifa ${context.pageNumber}',
            style: pw.TextStyle(font: regularFont, fontSize: 9),
          ),
        ),
        build: (context) {
          final children = <pw.Widget>[
            pw.SizedBox(height: 18),
            pw.Text(
              "${now.year}-yil o'quvchilar hisoboti",
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Yuklangan sana: ${_dateFormat.format(now)}',
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 20),
          ];

          final sortedClasses = [...classesSnapshot.docs]
            ..sort(
              (a, b) => a.data()['name'].toString().compareTo(
                b.data()['name'].toString(),
              ),
            );
          for (final classDocument in sortedClasses) {
            final classData = classDocument.data();
            final className = (classData['name'] ?? "Noma'lum sinf").toString();
            final students = [...(studentsByClass[classDocument.id] ?? [])]
              ..sort(
                (a, b) => (a['full_name'] ?? '').toString().compareTo(
                  (b['full_name'] ?? '').toString(),
                ),
              );

            children.addAll([
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                color: lightRed,
                child: pw.Text(
                  className,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: red,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
            ]);

            if (students.isEmpty) {
              children.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 14),
                  child: pw.Text(
                    "Bu sinfda o'quvchilar yo'q",
                    style: pw.TextStyle(
                      font: regularFont,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              );
              continue;
            }

            for (var index = 0; index < students.length; index++) {
              final student = students[index];
              final studentId = student['id'].toString();
              final loans = loansByStudent[studentId] ?? [];
              children.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${index + 1}. ${(student['full_name'] ?? "Noma'lum").toString()}',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      if (loans.isEmpty)
                        pw.Text(
                          'Yil davomida kitob olmagan',
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        )
                      else
                        pw.Table.fromTextArray(
                          headers: const [
                            'Kitob',
                            'Berilgan',
                            'Muddat',
                            'Holat',
                          ],
                          data: loans
                              .map(
                                (loan) => [
                                  (loan['book_title'] ?? "Noma'lum").toString(),
                                  _formatDate(loan['start_date']),
                                  _formatDate(loan['end_date']),
                                  loan['status'] == 'returned'
                                      ? 'Qabul qilingan'
                                      : 'Qaytarilmagan',
                                ],
                              )
                              .toList(),
                          headerStyle: pw.TextStyle(
                            font: boldFont,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            fontSize: 8,
                          ),
                          headerDecoration: pw.BoxDecoration(color: red),
                          cellStyle: pw.TextStyle(
                            font: regularFont,
                            fontSize: 8,
                          ),
                          cellPadding: const pw.EdgeInsets.all(5),
                          border: pw.TableBorder.all(color: PdfColors.grey300),
                        ),
                    ],
                  ),
                ),
              );
            }
          }
          return children;
        },
      ),
    );

    final bytes = Uint8List.fromList(await document.save());
    final fileName = 'oquvchilar_${now.year}.pdf';
    String? savedPath;

    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      // Mobil va Web uchun: ulashish dialogini chiqaradi
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } else {
      // Windows / Linux / macOS uchun: Documents papkasiga saqlaydi
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);
      savedPath = file.path;
    }
    await firestore.collection('system').doc('academic_year').set({
      'pdf_exported': true,
      'exported_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return savedPath;
  }

  static String _formatDate(dynamic value) {
    if (value is Timestamp) return _dateFormat.format(value.toDate());
    if (value is DateTime) return _dateFormat.format(value);
    return '-';
  }
}
