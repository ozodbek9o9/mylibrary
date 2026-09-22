import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'books_page.dart';
import 'home_page.dart';
import 'students_page.dart';
import 'notifications_page.dart';
import '../services/user_firestore.dart';
import '../services/auth_service.dart';

class LayoutPage extends StatefulWidget {
  const LayoutPage({super.key});

  @override
  State<LayoutPage> createState() => _LayoutPageState();
}

class _LayoutPageState extends State<LayoutPage> {
  int index = 0;
  final pages = const [HomePage(), BooksPage(), StudentsPage()];

  bool hasInternet = true;
  int _notificationCount = 0;
  bool _showNotificationBanner = false;
  bool _hasReceivedNotificationSnapshot = false;
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;
  Timer? _notificationBannerTimer;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkInitialInternet();
    _listenToNotifications();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      _updateConnectionStatus(results);
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _notificationsSubscription?.cancel();
    _notificationBannerTimer?.cancel();
    super.dispose();
  }

  void _listenToNotifications() {
    _notificationsSubscription = userFirestore
        .collection('borrowed_books')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
          final now = DateTime.now();
          final overdueCount = snapshot.docs.where((document) {
            final data = document.data();
            final dueDate = _readNotificationDate(data['end_date']);
            return dueDate != null && dueDate.isBefore(now);
          }).length;

          final shouldShowBanner = !_hasReceivedNotificationSnapshot
              ? overdueCount > 0
              : overdueCount > _notificationCount;
          _hasReceivedNotificationSnapshot = true;

          if (!mounted) return;
          setState(() => _notificationCount = overdueCount);
          if (shouldShowBanner) _showNotificationToast();
        });
  }

  void _showNotificationToast() {
    _notificationBannerTimer?.cancel();
    if (!mounted) return;
    setState(() => _showNotificationBanner = true);
    _notificationBannerTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted) setState(() => _showNotificationBanner = false);
    });
  }

  DateTime? _readNotificationDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Future<void> _checkInitialInternet() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnectionStatus(results);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    setState(() {
      hasInternet =
          results.isNotEmpty &&
          !results.every((r) => r == ConnectivityResult.none);
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
                label: const Text(
                  "Refresh",
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const _AppBrand(),
        actions: [
          IconButton.filledTonal(
            onPressed: _showNewAcademicYearModal,
            icon: const Icon(Icons.change_circle_outlined, color: Colors.red),
            tooltip: 'Yangi o\'quv yili',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xfffff0f0),
              foregroundColor: Colors.red,
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded),
                if (_notificationCount > 0)
                  Positioned(
                    top: -2,
                    right: -3,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xffc62828),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xfffff0f0),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Bildirishnomalar',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xfffff0f0),
              foregroundColor: const Color(0xffc62828),
            ),
          ),
          IconButton.filledTonal(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Chiqish',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xffc62828),
              foregroundColor: Colors.white,
              overlayColor: Colors.white24,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(index: index, children: pages),
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: IgnorePointer(
              ignoring: true,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.25),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _showNotificationBanner
                    ? _NotificationBanner(
                        key: const ValueKey('notification-banner'),
                        count: _notificationCount,
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('empty-notification-banner'),
                      ),
              ),
            ),
          ),
        ],
      ),
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

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chiqishni tasdiqlaysizmi?'),
        content: const Text('Akkauntdan chiqib, login sahifasiga qaytasiz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true) return;
    await AuthService.instance.signOut();
  }
}

class _AppBrand extends StatelessWidget {
  const _AppBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset('assets/app_icon.png', width: 34, height: 34),
        const SizedBox(width: 10),
        const Text(
          'Kutubxonam',
          style: TextStyle(
            color: Color(0xffc62828),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffffd6d6)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xffffe8e8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xffc62828),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '+$count xabar mavjud',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xffc62828),
              size: 20,
            ),
          ],
        ),
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
            const Text(
              "O'quv yilini almashtirish",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            const Expanded(
              child: Text(
                "Yangi o'quv yili uchun tizimni yangilash imkoniyati mavjud. Buni amalga oshirishdan oldin barcha o'zgarishlar haqida bilib oling.",
              ),
            ),
            ElevatedButton(
              onPressed: () => setState(() => step = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Keyingisi",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Batafsil ma'lumot",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            const Expanded(
              child: SingleChildScrollView(
                child: Text(
                  "Yangi o'quv yilini boshlash tizimdagi kitoblardan tashqari barcha ma'lumotlarni tozalaydi.\n\n"
                  "• Barcha sinflar o'chiriladi\n"
                  "• Barcha o'quvchilar o'chiriladi\n"
                  "• O'quvchilar va kitob olish-qaytarish tarixi o'chiriladi\n"
                  "• Bosh sahifadagi o'quv yiliga tegishli statistika tozalanadi\n\n"
                  "Kitoblar bazasi esa o'z holicha qoladi. Kitoblarning o'zi o'chirilmaydi.",
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => setState(() => step = 2),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Keyingisi",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Tasdiqlaysizmi?",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            const Expanded(
              child: Text(
                "Yangi o'quv yiliga o'tishga tayyormisiz? Bu amalni orqaga qaytarib bo'lmaydi.",
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Bekor qilish",
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startResetProcess,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Tasdiqlash",
                      style: TextStyle(color: Colors.white),
                    ),
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
            Text(
              loadingText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        );
      case 4:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 10),
            const Text(
              "Yangi o'quv yiliga o'tildi!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
    final exportStatus = await userFirestore
        .collection('system')
        .doc('academic_year')
        .get();
    final pdfExported = exportStatus.data()?['pdf_exported'] == true;
    if (!pdfExported) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('PDF hisobot kerak'),
            content: const Text(
              'Yangi o\'quv yiliga o\'tishdan oldin O\'quvchilar sahifasidagi "Yuklash" tugmasi orqali yillik PDF hisobotni yuklab oling.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Tushunarli',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() {
      step = 3;
      loadingText = "Jarayon boshlandi...";
    });

    await _wipeDatabase();

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() => loadingText = "Barcha ma'lumotlar tozalanmoqda...");
    }

    await Future.delayed(const Duration(seconds: 4));
    if (mounted) setState(() => loadingText = "Deyarli tayyor...");

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => step = 4);
  }

  Future<void> _wipeDatabase() async {
    final firestore = userFirestore;

    // The current UI stores students and borrowing history at the top level.
    await _deleteCollection(firestore.collection('borrowed_books'));
    await _deleteCollection(firestore.collection('loans'));
    await _deleteCollection(firestore.collection('students'));

    // Also remove data written by the older nested class/student model.
    final classes = await firestore.collection('classes').get();
    for (final classDoc in classes.docs) {
      final nestedStudents = await classDoc.reference
          .collection('students')
          .get();
      for (final studentDoc in nestedStudents.docs) {
        await _deleteCollection(studentDoc.reference.collection('history'));
        await studentDoc.reference.delete();
      }
      await classDoc.reference.delete();
    }

    await firestore.collection('system').doc('academic_year').set({
      'pdf_exported': false,
      'reset_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final documents = await collection.get();
    for (var index = 0; index < documents.docs.length; index += 450) {
      final batch = userFirestore.batch();
      final end = (index + 450).clamp(0, documents.docs.length);
      for (final document in documents.docs.sublist(index, end)) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }
}
