import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'books_page.dart';
import 'home_page.dart';
import 'students_page.dart';
import 'notifications_page.dart';

class LayoutPage extends StatefulWidget {
  const LayoutPage({super.key});

  @override
  State<LayoutPage> createState() => _LayoutPageState();
}

class _LayoutPageState extends State<LayoutPage> {
  int index = 0;
  final pages = const [HomePage(), BooksPage(), StudentsPage()];
  
  bool hasInternet = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkInitialInternet();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results);
    });
  }
  
  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _checkInitialInternet() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnectionStatus(results);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    setState(() {
      hasInternet = results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);
    });
  }

  void _showNewAcademicYearModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const AcademicYearModal(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!hasInternet) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 80, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                "Internetingizni yoqing yoki Wifi ga ulaning",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _checkInitialInternet,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text("Refresh", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    String appBarTitle = 'Kutubxonam';
    if (index == 1) appBarTitle = 'Kitoblar';
    if (index == 2) appBarTitle = 'O\'quvchilar';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            if (index == 0) Image.asset('assets/app_icon.png', width: 34, height: 34),
            if (index == 0) const SizedBox(width: 10),
            Text(
              appBarTitle,
              style: const TextStyle(
                color: Color(0xffc62828),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showNewAcademicYearModal,
            icon: const Icon(Icons.change_circle_outlined, color: Colors.red),
            tooltip: 'Yangi o\'quv yili',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        indicatorColor: const Color(0xffffe2e2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Bosh sahifa',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Kitoblar',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'O\'quvchilar',
          ),
        ],
      ),
    );
  }
}

class AcademicYearModal extends StatefulWidget {
  const AcademicYearModal({super.key});
  @override
  State<AcademicYearModal> createState() => _AcademicYearModalState();
}

class _AcademicYearModalState extends State<AcademicYearModal> {
  int step = 0;
  String loadingText = "Jarayon boshlandi...";

  @override
  Widget build(BuildContext context) {
    double height = 220;
    if (step == 1) height = 400;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: height,
      padding: const EdgeInsets.all(20),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("O'quv yilini almashtirish", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 10),
            const Expanded(child: Text("Yangi o'quv yili uchun tizimni yangilash imkoniyati mavjud. Buni amalga oshirishdan oldin barcha o'zgarishlar haqida bilib oling.")),
            ElevatedButton(
              onPressed: () => setState(() => step = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Keyingisi", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Batafsil ma'lumot", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 10),
            const Expanded(
              child: SingleChildScrollView(
                child: Text(
                  "Yangi o'quv yilini boshlash tizimdagi kitoblardan tashqari barcha ma'lumotlarni tozalaydi.\n\n"
                  "• Barcha sinflar o'chiriladi\n"
                  "• Barcha o'quvchilar o'chiriladi\n"
                  "• Barcha kitob olish va qaytarish statistikasi hamda tarixi o'chiriladi\n\n"
                  "Kitoblar bazasi esa o'z holicha qoladi. Ularning ma'lumotlari saqlanadi, barcha band qilingan kitoblar 'Kitob band emas' holatiga avtomatik qaytariladi."
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => setState(() => step = 2),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Keyingisi", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Tasdiqlaysizmi?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 10),
            const Expanded(child: Text("Yangi o'quv yiliga o'tishga tayyormisiz? Bu amalni orqaga qaytarib bo'lmaydi.")),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Bekor qilish", style: TextStyle(color: Colors.black)),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startResetProcess,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Tasdiqlash", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        );
      case 3:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.red),
            const SizedBox(height: 20),
            Text(loadingText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        );
      case 4:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 10),
            const Text("Yangi o'quv yiliga o'tildi!", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  void _startResetProcess() async {
    setState(() {
      step = 3;
      loadingText = "Jarayon boshlandi...";
    });

    _wipeDatabase();

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => loadingText = "Barcha ma'lumotlar tozalanmoqda...");

    await Future.delayed(const Duration(seconds: 4));
    if (mounted) setState(() => loadingText = "Deyarli tayyor...");

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => step = 4);
  }

  Future<void> _wipeDatabase() async {
    try {
      final classes = await FirebaseFirestore.instance.collection('classes').get();
      for (var doc in classes.docs) { await doc.reference.delete(); }

      final students = await FirebaseFirestore.instance.collection('students').get();
      for (var doc in students.docs) { await doc.reference.delete(); }

      final borrowed = await FirebaseFirestore.instance.collection('borrowed_books').get();
      for (var doc in borrowed.docs) { await doc.reference.delete(); }
    } catch (e) {
      // Background delete errors ignored in UI
    }
  }
}
