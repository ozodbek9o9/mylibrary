import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isChecking = false;
  bool _showUpdatePanel = false;
  bool _updateAvailable = false;
  String _releaseVersion = '';
  String _releaseNotes = '';
  String _releaseUrl =
      'https://github.com/ozodbek9o9/mylibrary/releases/latest';
  String _statusMessage = '';

  Future<void> _toggleTheme(bool value) async {
    final nextMode = value ? ThemeMode.dark : ThemeMode.light;
    appThemeMode.value = nextMode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'theme_mode',
      nextMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  Future<void> _checkForUpdates() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _showUpdatePanel = true;
      _statusMessage = 'Yangilanish borligi tekshirilmoqda.....';
      _updateAvailable = false;
      _releaseVersion = '';
      _releaseNotes = '';
    });

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/ozodbek9o9/mylibrary/releases?per_page=100',
            ),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Mening-Kutubxonam-App',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload is! List) {
          throw const FormatException('GitHub releases javobi noto\'g\'ri');
        }

        final releases = payload
            .whereType<Map<String, dynamic>>()
            .where(
              (release) =>
                  release['draft'] != true &&
                  release['published_at'] != null &&
                  release['tag_name'] != null,
            )
            .toList();
        releases.sort((first, second) {
          final firstDate =
              DateTime.tryParse(first['published_at'].toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          final secondDate =
              DateTime.tryParse(second['published_at'].toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          return secondDate.compareTo(firstDate);
        });

        if (releases.isEmpty) {
          setState(() {
            _isChecking = false;
            _updateAvailable = false;
            _statusMessage = 'GitHub’da e’lon qilingan release topilmadi';
          });
          return;
        }

        final release = releases.first;
        final version = release['tag_name'].toString().trim();
        final isUpdateAvailable =
            _compareVersions(version, packageInfo.version) > 0;
        final notes = (release['body'] ?? '').toString();
        final url = (release['html_url'] ?? _releaseUrl).toString();

        setState(() {
          _isChecking = false;
          _updateAvailable = isUpdateAvailable;
          _releaseVersion = version;
          _releaseNotes = notes.trim();
          _releaseUrl = url;
          _statusMessage = isUpdateAvailable
              ? 'Yangi versiya mavjud'
              : 'Siz allaqachon eng oxirgi versiyadasiz (${packageInfo.version})';
        });
        return;
      }

      if (response.statusCode == 404) {
        setState(() {
          _isChecking = false;
          _updateAvailable = false;
          _statusMessage = 'GitHub repo yoki release ochiq emas. Private repo’ni ilova tokenisiz tekshirib bo\'lmaydi.';
          _releaseVersion = '';
          _releaseNotes = '';
        });
        return;
      }

      if (response.statusCode == 403) {
        setState(() {
          _isChecking = false;
          _updateAvailable = false;
          _statusMessage = 'GitHub so\'rovlari vaqtincha cheklangan. Birozdan keyin qayta urinib ko\'ring.';
        });
        return;
      }

      setState(() {
        _isChecking = false;
        _updateAvailable = false;
        _statusMessage =
            'GitHub tekshiruvida xatolik yuz berdi (HTTP ${response.statusCode})';
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _updateAvailable = false;
        _statusMessage = 'GitHub javobi kutilgan vaqtda kelmadi';
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _updateAvailable = false;
        _statusMessage = 'Release versiyasi formatini aniqlab bo\'lmadi';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _updateAvailable = false;
        _statusMessage = 'Internet yoki GitHub bilan bog\'lanishda xatolik';
      });
    }
  }

  int _compareVersions(String first, String second) {
    final firstVersion = _parseVersion(first);
    final secondVersion = _parseVersion(second);

    for (var index = 0; index < 3; index++) {
      final comparison = firstVersion.core[index].compareTo(
        secondVersion.core[index],
      );
      if (comparison != 0) return comparison;
    }

    final firstPreRelease = firstVersion.prerelease;
    final secondPreRelease = secondVersion.prerelease;
    if (firstPreRelease == null && secondPreRelease == null) return 0;
    if (firstPreRelease == null) return 1;
    if (secondPreRelease == null) return -1;

    final sharedLength = firstPreRelease.length < secondPreRelease.length
        ? firstPreRelease.length
        : secondPreRelease.length;
    for (var index = 0; index < sharedLength; index++) {
      final firstPart = firstPreRelease[index];
      final secondPart = secondPreRelease[index];
      final firstNumber = int.tryParse(firstPart);
      final secondNumber = int.tryParse(secondPart);

      if (firstNumber != null && secondNumber != null) {
        final comparison = firstNumber.compareTo(secondNumber);
        if (comparison != 0) return comparison;
      } else if (firstNumber != null) {
        return -1;
      } else if (secondNumber != null) {
        return 1;
      } else {
        final comparison = firstPart.compareTo(secondPart);
        if (comparison != 0) return comparison;
      }
    }

    return firstPreRelease.length.compareTo(secondPreRelease.length);
  }

  ({List<int> core, List<String>? prerelease}) _parseVersion(String value) {
    var normalized = value.trim().replaceFirst(RegExp(r'^[vV]'), '');
    normalized = normalized.split('+').first;
    final separator = normalized.indexOf('-');
    final coreValue = separator < 0
        ? normalized
        : normalized.substring(0, separator);
    final core = coreValue.split('.').map(int.tryParse).toList();

    if (core.length != 3 || core.any((part) => part == null)) {
      throw FormatException('Invalid semantic version: $value');
    }

    final prerelease = separator < 0
        ? null
        : normalized.substring(separator + 1).split('.');
    if (prerelease != null && prerelease.any((part) => part.isEmpty)) {
      throw FormatException('Invalid semantic version: $value');
    }

    return (core: core.cast<int>(), prerelease: prerelease);
  }

  Future<void> _downloadRelease() async {
    final targetUrl = Uri.parse(_releaseUrl);
    if (await canLaunchUrl(targetUrl)) {
      await launchUrl(targetUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? const Color(0xffff858b) : const Color(0xffc62828);
    final accentSurface = isDark
        ? const Color(0xff382326)
        : const Color(0xfffff0f0);
    final borderColor = theme.dividerColor.withValues(alpha: 0.35);
    final mutedText = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: borderColor),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            tooltip: 'Orqaga',
            style: IconButton.styleFrom(
              backgroundColor: accentSurface,
              foregroundColor: accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        title: const Text(
          'Sozlamalar',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              onPressed: _logout,
              tooltip: 'Chiqish',
              icon: const Icon(Icons.logout_rounded),
              style: IconButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xffa62b32)
                    : const Color(0xffc62828),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              elevation: 0,
              shape: cardShape,
              color: theme.cardColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentSurface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dark mode',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isDark
                                ? 'Tungi ko‘rinish yoqilgan'
                                : 'Yorug‘ ko‘rinish',
                            style: TextStyle(color: mutedText, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.wb_sunny_outlined,
                      size: 18,
                      color: isDark ? mutedText : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Switch.adaptive(
                      value: isDark,
                      activeThumbColor: accent,
                      activeTrackColor: isDark
                          ? const Color(0xff63363b)
                          : const Color(0xffffd6d6),
                      onChanged: _toggleTheme,
                    ),
                    Icon(
                      Icons.dark_mode_rounded,
                      size: 18,
                      color: isDark ? accent : mutedText,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              elevation: 0,
              shape: cardShape,
              color: theme.cardColor,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _isChecking ? null : _checkForUpdates,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accentSurface,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.system_update_alt_rounded,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Yangilanish borligini tekshirish',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: accentSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.arrow_forward_rounded, color: accent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_showUpdatePanel) ...[
              const SizedBox(height: 18),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff211b1d) : theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.16 : 0.035,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: _isChecking
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Yangilanish borligi tekshirilmoqda.....',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _updateAvailable
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _statusMessage.isEmpty
                                ? 'Yangi versiya mavjud'
                                : _statusMessage,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (_releaseVersion.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: accentSurface,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _releaseVersion,
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          if (_releaseNotes.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              _releaseNotes,
                              style: TextStyle(height: 1.5, color: mutedText),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _downloadRelease,
                                  icon: const Icon(Icons.download_rounded),
                                  label: const Text('Yuklab olish'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      setState(() => _showUpdatePanel = false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: accent,
                                    side: BorderSide(
                                      color: isDark
                                          ? accent.withValues(alpha: 0.4)
                                          : const Color(0xfff4b5b5),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Keyinroq'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _statusMessage.startsWith('Siz allaqachon')
                                    ? Icons.check_circle_rounded
                                    : Icons.info_outline_rounded,
                                color:
                                    _statusMessage.startsWith('Siz allaqachon')
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _statusMessage,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
