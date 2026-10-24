import 'package:android_intent_plus/android_intent.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:url_launcher/url_launcher.dart';

/// Backend logic: voice/text -> phone action.
/// 1) Pehle real installed-apps list se match karta hai -> KOI BHI app khul sakti hai
///    (Snapchat, Contacts, Gallery, Phone, WhatsApp, A to Z har app).
/// 2) Special actions (call, search, camera, settings, maps) alag se handle hote hain.
class CommandService {
  List<AppInfo> _apps = [];
  bool _loaded = false;

  static const _urdu = <String, String>{
    'یوٹیوب': 'youtube', 'واٹس ایپ': 'whatsapp', 'فیس بک': 'facebook',
    'کیمرہ': 'camera', 'سیٹنگز': 'settings', 'گوگل': 'google',
    'انسٹاگرام': 'instagram', 'میپس': 'maps', 'بلوٹوتھ': 'bluetooth',
    'وائی فائی': 'wifi', 'گیلری': 'gallery', 'رابطے': 'contacts',
    'فون': 'phone', 'سنیپ چیٹ': 'snapchat', 'تصویریں': 'gallery',
  };

  static const _openWords = [
    'open', 'launch', 'start', 'kholo', 'khol', 'karo', 'kro', 'kardo',
    'application', 'app', 'please', 'mujhe', 'mera', 'do', 'ko'
  ];

  /// Call once (e.g. app start) so the app list is ready before first command.
  Future<void> loadApps() async {
    if (_loaded) return;
    try {
      _apps = await InstalledApps.getInstalledApps(true, true);
      _loaded = true;
    } catch (_) {
      _apps = [];
    }
  }

  Future<String> run(String raw) async {
    if (!_loaded) await loadApps();
    var q = raw.toLowerCase().trim();
    _urdu.forEach((k, v) => q = q.replaceAll(k, v));
    if (q.isEmpty) return 'Kuch sunai nahi diya.';

    // ---- system screens ----
    if (q.contains('camera')) {
      return _intent('android.media.action.STILL_IMAGE_CAMERA', 'Camera khul gaya');
    }
    if (q.contains('wifi') || q.contains('wi-fi')) {
      return _intent('android.settings.WIFI_SETTINGS', 'WiFi settings khul gayi');
    }
    if (q.contains('bluetooth')) {
      return _intent('android.settings.BLUETOOTH_SETTINGS', 'Bluetooth settings khul gayi');
    }
    if (q.contains('setting')) {
      return _intent('android.settings.SETTINGS', 'Settings khul gayi');
    }

    // ---- call / dialer ----
    final num = RegExp(r'(\+?\d[\d\s-]{6,})').firstMatch(q);
    if ((q.contains('call') || q.contains('dial')) && num != null) {
      final n = num.group(1)!.replaceAll(RegExp(r'[\s-]'), '');
      return _open('tel:$n', '$n ko dial kar raha hoon');
    }
    if (q.contains('dial') || (q.contains('phone') && q.contains('kholo') == false && num == null && !q.contains('gallery'))) {
      final r = await _intentTry('android.intent.action.DIAL', 'Dialer khul gaya');
      if (r != null) return r;
    }

    // ---- youtube search / play ----
    if (q.contains('youtube') && (q.contains('search') || q.contains('play') || q.contains('chala'))) {
      final term = _clean(q, ['youtube', 'search', 'play', 'on', 'par', 'pe', 'per', 'chalao', 'chala', ..._openWords]);
      if (term.isNotEmpty) {
        return _open('https://www.youtube.com/results?search_query=${Uri.encodeComponent(term)}',
            'YouTube par "$term" search kar diya');
      }
    }

    // ---- google search ----
    if (q.startsWith('search') || q.contains('google search') || q.contains('search kar')) {
      final term = _clean(q, ['google', 'search', 'for', ..._openWords]);
      return _open('https://www.google.com/search?q=${Uri.encodeComponent(term)}', '"$term" search ho raha hai');
    }

    // ---- maps / navigation ----
    if (q.contains('navigate') || q.contains('directions')) {
      final term = _clean(q, ['navigate', 'to', 'directions', ..._openWords]);
      return _open('geo:0,0?q=${Uri.encodeComponent(term)}', '$term ka rasta khol raha hoon');
    }

    // ---- contacts ----
    if (q.contains('contact')) {
      final app = _findApp('contacts') ?? _findApp('people');
      if (app != null) return _launch(app, 'Contacts khul gaye');
    }

    // ---- gallery / photos ----
    if (q.contains('gallery') || q.contains('photo')) {
      final app = _findApp('gallery') ?? _findApp('photos');
      if (app != null) return _launch(app, 'Gallery khul gayi');
    }

    // ---- ANY installed app, by real name (Snapchat, WhatsApp, Phone, A-Z sab) ----
    final cleanName = _clean(q, _openWords);
    final match = _findApp(cleanName) ?? _findApp(q);
    if (match != null) return _launch(match, '${match.name} khol raha hoon');

    // ---- fallback: common apps even if no exact name match found ----
    const fallbackWeb = <String, String>{
      'facebook': 'https://www.facebook.com',
      'instagram': 'https://www.instagram.com',
      'tiktok': 'https://www.tiktok.com',
      'twitter': 'https://x.com',
      'gmail': 'https://mail.google.com',
      'maps': 'https://www.google.com/maps',
      'chrome': 'https://www.google.com',
      'google': 'https://www.google.com',
      'play store': 'https://play.google.com/store',
      'youtube': 'https://www.youtube.com',
    };
    for (final e in fallbackWeb.entries) {
      if (q.contains(e.key)) return _open(e.value, '${e.key} khol raha hoon');
    }

    return 'Ye app/command nahi mili: "$raw"\nApp ka sahi naam bol kar dobara try karein, jaise "Snapchat kholo".';
  }

  AppInfo? _findApp(String phrase) {
    phrase = phrase.trim().toLowerCase();
    if (_apps.isEmpty || phrase.isEmpty) return null;
    AppInfo? best;
    int bestScore = 0;
    for (final a in _apps) {
      final name = a.name.toLowerCase();
      if (name.isEmpty) continue;
      int score = 0;
      if (phrase == name) {
        score = 1000;
      } else if (phrase.contains(name) && name.length >= 3) {
        score = name.length;
      } else if (name.contains(phrase) && phrase.length >= 3) {
        score = phrase.length;
      }
      if (score > bestScore) {
        bestScore = score;
        best = a;
      }
    }
    return bestScore > 0 ? best : null;
  }

  String _clean(String q, List<String> stop) {
    final words = q.split(RegExp(r'\s+'))..removeWhere(stop.contains);
    return words.join(' ').trim();
  }

  Future<String> _launch(AppInfo app, String ok) async {
    try {
      await InstalledApps.startApp(app.packageName);
      return ok;
    } catch (e) {
      return '${app.name} open nahi ho saki';
    }
  }

  Future<String> _open(String url, String ok) async {
    try {
      final done = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return done ? ok : 'Open nahi ho saka';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> _intent(String action, String ok) async {
    try {
      await AndroidIntent(action: action).launch();
      return ok;
    } catch (e) {
      return 'Ye action is phone par nahi chala';
    }
  }

  Future<String?> _intentTry(String action, String ok) async {
    try {
      await AndroidIntent(action: action).launch();
      return ok;
    } catch (_) {
      return null;
    }
  }
}