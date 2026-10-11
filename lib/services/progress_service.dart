import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressService extends ChangeNotifier {
  ProgressService._();

  static final ProgressService instance = ProgressService._();

  static const int dailyGoalSeconds = 15 * 60;
  static const int xpPerLevel = 100;

  SharedPreferences? _prefs;

  int xp = 0;
  int streak = 0;
  String lastActiveDay = '';
  int nextLetter = 0;
  int _todaySeconds = 0;
  String _secondsDay = '';
  final Set<int> completed = <int>{};
  final Set<int> review = <int>{};

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    xp = prefs.getInt('xp') ?? 0;
    streak = prefs.getInt('streak') ?? 0;
    lastActiveDay = prefs.getString('lastActiveDay') ?? '';
    nextLetter = prefs.getInt('nextLetter') ?? 0;
    _todaySeconds = prefs.getInt('todaySeconds') ?? 0;
    _secondsDay = prefs.getString('secondsDay') ?? '';
    completed
      ..clear()
      ..addAll((prefs.getStringList('completed') ?? <String>[]).map(int.parse));
    review
      ..clear()
      ..addAll((prefs.getStringList('review') ?? <String>[]).map(int.parse));
    notifyListeners();
  }

  static String _dayKey(DateTime d) {
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-$m-$day';
  }

  int get level => xp ~/ xpPerLevel + 1;

  int get xpInLevel => xp % xpPerLevel;

  double get levelFraction => xpInLevel / xpPerLevel;

  int get currentStreak {
    if (lastActiveDay.isEmpty) return 0;
    final DateTime now = DateTime.now();
    final String today = _dayKey(now);
    final String yesterday = _dayKey(DateTime(now.year, now.month, now.day - 1));
    if (lastActiveDay == today || lastActiveDay == yesterday) return streak;
    return 0;
  }

  int get todaySeconds {
    final String today = _dayKey(DateTime.now());
    return _secondsDay == today ? _todaySeconds : 0;
  }

  double get dailyGoalFraction =>
      (todaySeconds / dailyGoalSeconds).clamp(0.0, 1.0);

  void _touchStreak() {
    final DateTime now = DateTime.now();
    final String today = _dayKey(now);
    if (lastActiveDay == today) return;
    final String yesterday = _dayKey(DateTime(now.year, now.month, now.day - 1));
    streak = lastActiveDay == yesterday ? streak + 1 : 1;
    lastActiveDay = today;
  }

  Future<void> addXp(int amount) async {
    xp += amount;
    _touchStreak();
    await _save();
  }

  Future<void> completeLetter(int order) async {
    completed.add(order);
    if (order > nextLetter) nextLetter = order;
    review.remove(order);
    _touchStreak();
    await _save();
  }

  Future<void> addReview(int order) async {
    review.add(order);
    await _save();
  }

  Future<void> addSeconds(int seconds) async {
    if (seconds <= 0) return;
    final String today = _dayKey(DateTime.now());
    if (_secondsDay != today) {
      _secondsDay = today;
      _todaySeconds = 0;
    }
    _todaySeconds += seconds;
    await _save();
  }

  Future<void> _save() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs != null) {
      await prefs.setInt('xp', xp);
      await prefs.setInt('streak', streak);
      await prefs.setString('lastActiveDay', lastActiveDay);
      await prefs.setInt('nextLetter', nextLetter);
      await prefs.setInt('todaySeconds', _todaySeconds);
      await prefs.setString('secondsDay', _secondsDay);
      await prefs.setStringList(
          'completed', completed.map((int e) => e.toString()).toList());
      await prefs.setStringList(
          'review', review.map((int e) => e.toString()).toList());
    }
    notifyListeners();
  }
}
