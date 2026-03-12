import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  await AppStore.init();
  await Notifier.init();
  runApp(const MasterApp());
}

/// ==============================
/// STORAGE
/// ==============================
class AppStore {
  static late SharedPreferences _prefs;

  static const _kHabits = "habits";
  static const _kLogs = "logs";
  static const _kWeights = "weights";
  static const _kReminder = "reminder";

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    if (!_prefs.containsKey(_kHabits)) {
      await _prefs.setStringList(_kHabits, [
        "Wake up early",
        "Exercise / Gym",
        "Reading",
        "Deep Work / Project",
        "Meditation",
        "No Junk Food",
        "Learning",
        "Goal Journaling",
        "Skill Practice",
        "Cold Shower",
        "Budget Tracking",
        "Plan Tomorrow",
        "No Social Media (1h)",
        "Drink Water (2L)",
        "Walk 6k steps",
        "Stretching",
        "Sleep before 11",
        "Healthy Breakfast",
        "Code Practice",
        "Family Time",
        "Language Practice",
        "Clean Desk",
        "No Sugar",
        "Gratitude",
        "Review Goals",
      ]);
    }

    if (!_prefs.containsKey(_kLogs)) {
      await _prefs.setString(_kLogs, jsonEncode({}));
    }

    if (!_prefs.containsKey(_kWeights)) {
      await _prefs.setString(_kWeights, jsonEncode({}));
    }

    if (!_prefs.containsKey(_kReminder)) {
      await _prefs.setString(_kReminder, "");
    }
  }

  static String dateKey(DateTime d) => DateFormat("yyyy-MM-dd").format(d);

  static List<String> habits() => _prefs.getStringList(_kHabits) ?? [];

  static Future<void> setHabits(List<String> list) async {
    await _prefs.setStringList(_kHabits, list);
    final today = DateTime.now();
    final log = getDayLog(today);
    final fixed = _fitLogToHabits(log, list.length);
    await setDayLog(today, fixed);
  }

  static Map<String, dynamic> _logsMap() {
    final raw = _prefs.getString(_kLogs) ?? "{}";
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<void> _setLogsMap(Map<String, dynamic> map) async {
    await _prefs.setString(_kLogs, jsonEncode(map));
  }

  static Map<String, dynamic> _weightsMap() {
    final raw = _prefs.getString(_kWeights) ?? "{}";
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<void> _setWeightsMap(Map<String, dynamic> map) async {
    await _prefs.setString(_kWeights, jsonEncode(map));
  }

  static List<int> getDayLog(DateTime d) {
    final habitCount = habits().length;
    final map = _logsMap();
    final key = dateKey(d);
    final value = map[key];

    if (value == null) {
      return List<int>.filled(habitCount, 0);
    }

    final list = (value as List).map((e) => (e as num).toInt()).toList();
    return _fitLogToHabits(list, habitCount);
  }

  static List<int> _fitLogToHabits(List<int> log, int habitCount) {
    if (log.length < habitCount) {
      return [...log, ...List<int>.filled(habitCount - log.length, 0)];
    }
    if (log.length > habitCount) {
      return log.sublist(0, habitCount);
    }
    return log;
  }

  static Future<void> setDayLog(DateTime d, List<int> log) async {
    final map = _logsMap();
    map[dateKey(d)] = log;
    await _setLogsMap(map);
  }

  static double? weight(DateTime d) {
    final map = _weightsMap();
    final value = map[dateKey(d)];
    if (value == null) return null;
    return (value as num).toDouble();
  }

  static Future<void> setWeight(DateTime d, double w) async {
    final map = _weightsMap();
    map[dateKey(d)] = w;
    await _setWeightsMap(map);
  }

  static String reminder() => _prefs.getString(_kReminder) ?? "";

  static Future<void> setReminder(String hhmm) async {
    await _prefs.setString(_kReminder, hhmm);
  }

  static Map<String, dynamic> allLogs() => _logsMap();

  static List<MapEntry<DateTime, double>> weightSeries(int daysBack) {
    final map = _weightsMap();
    final now = DateTime.now();
    final out = <MapEntry<DateTime, double>>[];

    for (int i = daysBack - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final value = map[dateKey(d)];
      if (value != null) {
        out.add(MapEntry(d, (value as num).toDouble()));
      }
    }
    return out;
  }
}

/// ==============================
/// NOTIFICATIONS
/// ==============================
class Notifier {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  static Future<void> scheduleDaily(int hour, int minute) async {
    await _plugin.cancel(1);

    const androidDetails = AndroidNotificationDetails(
      "master_reminder",
      "MASTER Reminder",
      channelDescription: "Daily reminder to update habits and weight",
      importance: Importance.max,
      priority: Priority.high,
    );

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (next.isBefore(now)) {
      next = next.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      1,
      "MASTER Reminder",
      "Update today's habits and weight.",
      next,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}

/// ==============================
/// STATS
/// ==============================
class Stats {
  static double dayScore(DateTime d) {
    final habits = AppStore.habits();
    if (habits.isEmpty) return 0;

    final log = AppStore.getDayLog(d);
    final done = log.where((x) => x == 1).length;
    return done / habits.length;
  }

  static bool dayHasAnyLog(DateTime d) {
    final log = AppStore.getDayLog(d);
    final anyHabit = log.any((x) => x == 1);
    final anyWeight = AppStore.weight(d) != null;
    return anyHabit || anyWeight;
  }

  static int habitStreak(int habitIndex, DateTime today) {
    int streak = 0;

    for (int i = 0; i < 3650; i++) {
      final day = today.subtract(Duration(days: i));
      final log = AppStore.getDayLog(day);

      if (habitIndex >= log.length) {
        break;
      }

      if (log[habitIndex] == 1) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  static int habitLongestStreak(int habitIndex) {
    final logs = AppStore.allLogs();
    if (logs.isEmpty) return 0;

    final keys = logs.keys.toList()..sort();
    int best = 0;
    int current = 0;
    String? prev;

    for (final key in keys) {
      final list = (logs[key] as List).map((e) => (e as num).toInt()).toList();
      final done = habitIndex < list.length && list[habitIndex] == 1;

      if (prev == null) {
        current = done ? 1 : 0;
      } else {
        final prevDate = DateTime.parse(prev);
        final curDate = DateTime.parse(key);
        final isNext = curDate.difference(prevDate).inDays == 1;

        if (!isNext) {
          current = 0;
        }

        current = done ? (current + 1) : 0;
      }

      if (current > best) {
        best = current;
      }

      prev = key;
    }

    return best;
  }

  static List<String> weakHabits(int days, {int top = 3}) {
    final habits = AppStore.habits();
    if (habits.isEmpty) return [];

    final totals = List<double>.filled(habits.length, 0);
    final today = DateTime.now();
    int countedDays = 0;

    for (int i = 0; i < days; i++) {
      final d = today.subtract(Duration(days: i));
      if (!dayHasAnyLog(d)) continue;

      countedDays++;
      final log = AppStore.getDayLog(d);

      for (int h = 0; h < habits.length; h++) {
        totals[h] += (log[h] == 1) ? 1 : 0;
      }
    }

    if (countedDays < 3) return [];

    final rates = List.generate(habits.length, (i) => totals[i] / countedDays);
    final idx = List.generate(habits.length, (i) => i);
    idx.sort((a, b) => rates[a].compareTo(rates[b]));

    return idx.take(top).map((i) => habits[i]).toList();
  }

  static double avgScore(int days) {
    final habits = AppStore.habits();
    if (habits.isEmpty) return 0;

    final today = DateTime.now();
    double sum = 0;
    int count = 0;

    for (int i = 0; i < days; i++) {
      final d = today.subtract(Duration(days: i));
      if (!dayHasAnyLog(d)) continue;
      sum += dayScore(d);
      count++;
    }

    return count == 0 ? 0 : sum / count;
  }
}

/// ==============================
/// BOT
/// ==============================
class ChartBot {
  static String fullAnalysisToday() {
    final habits = AppStore.habits();
    final today = DateTime.now();
    final log = AppStore.getDayLog(today);
    final done = log.where((x) => x == 1).length;
    final score = Stats.dayScore(today);

    final weight = AppStore.weight(today);
    final w7 = AppStore.weightSeries(7);
    double? weeklyChange;
    if (w7.length >= 2) {
      weeklyChange = w7.last.value - w7.first.value;
    }

    final weak = Stats.weakHabits(7, top: 3);
    final focus = weak.isNotEmpty ? weak.first : "your weakest habit";

    final plan = <String>[
      "Do the hardest habit first before distractions.",
      if (weak.isNotEmpty)
        "Make ${weak.first} a 5-minute minimum version.",
      "Batch 2 habits together, for example after shower to meditation.",
      "Set a fixed update time of 1 minute.",
    ];

    return [
      "TODAY SUMMARY",
      "Habits: $done / ${habits.length} (${(score * 100).round()}%)",
      "Weight: ${weight == null ? "not entered" : "${weight.toStringAsFixed(1)} kg"}",
      if (weeklyChange != null)
        "7-day weight change: ${weeklyChange >= 0 ? "+" : ""}${weeklyChange.toStringAsFixed(1)} kg",
      "",
      "TOP ISSUES (last 7 days)",
      if (weak.isEmpty)
        "Not enough data yet. Log 3 to 5 days and I’ll detect patterns.",
      ...weak.map((h) => "Low consistency: $h"),
      "",
      "FOCUS FOR TOMORROW",
      "Focus habit: $focus",
      "",
      "TOMORROW ACTION PLAN",
      ...plan,
      "",
      "3 SMALL COMMITMENTS",
      "10 minutes on the focus habit",
      "Complete 1 hard habit before 12 PM",
      "Update MASTER at night for 1 minute",
      "",
      "ONE LINE",
      "Consistency beats intensity. Don’t miss the update.",
    ].join("\n");
  }

  static String weeklyReview() {
    final avg = Stats.avgScore(7);
    final weak = Stats.weakHabits(7, top: 5);

    final w14 = AppStore.weightSeries(14);
    String weightLine = "Weight: not enough data yet.";
    if (w14.length >= 2) {
      final change = w14.last.value - w14.first.value;
      weightLine =
      "Weight 14-day change: ${change >= 0 ? "+" : ""}${change.toStringAsFixed(1)} kg";
    }

    return [
      "WEEKLY REVIEW (LAST 7 DAYS)",
      "Avg productivity: ${(avg * 100).round()}%",
      weightLine,
      "",
      "WHAT’S WORKING",
      "Keep your top 2 habits stable. Don’t change them.",
      "",
      "WEAK HABITS",
      if (weak.isEmpty) "Not enough data yet.",
      ...weak,
      "",
      "NEXT WEEK PLAN",
      "Pick 1 weak habit and reduce it to a 5-minute version",
      "Fix a time and do it at the same time daily",
      "Track weight daily even if habits are low",
    ].join("\n");
  }
}

/// ==============================
/// APP
/// ==============================
class MasterApp extends StatelessWidget {
  const MasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "MASTER",
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      ),
      home: const Tabs(),
    );
  }
}

class Tabs extends StatefulWidget {
  const Tabs({super.key});

  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> {
  int idx = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayTab(onChanged: () => setState(() {})),
      const HeatmapTab(),
      const AnalyticsTab(),
      const ReportsTab(),
      const BotTab(),
    ];

    return Scaffold(
      body: pages[idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => idx = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.today), label: "Today"),
          BottomNavigationBarItem(icon: Icon(Icons.grid_on), label: "Heatmap"),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: "Analytics"),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: "Reports"),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: "Bot"),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
          setState(() {});
        },
        child: const Icon(Icons.settings),
      ),
    );
  }
}

/// ==============================
/// TODAY TAB
/// ==============================
class TodayTab extends StatefulWidget {
  final VoidCallback onChanged;
  const TodayTab({super.key, required this.onChanged});

  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> {
  List<String> habits = [];
  List<int> log = [];
  final weightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    habits = AppStore.habits();
    log = AppStore.getDayLog(DateTime.now());
    final w = AppStore.weight(DateTime.now());
    weightCtrl.text = w == null ? "" : w.toStringAsFixed(1);
    setState(() {});
  }

  Future<void> _saveWeight() async {
    final text = weightCtrl.text.trim();
    final w = double.tryParse(text);

    if (w == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid weight (kg)")),
      );
      return;
    }

    await AppStore.setWeight(DateTime.now(), w);
    widget.onChanged();
    setState(() {});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Weight saved ✅")),
    );
  }

  Future<void> _addHabit() async {
    if (habits.length >= 25) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Max 25 habits reached")),
      );
      return;
    }

    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Add Habit"),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: "Habit name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, c.text.trim()),
            child: const Text("Add"),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;
    if (habits.contains(name)) return;

    habits.add(name);
    await AppStore.setHabits(habits);

    log = AppStore.getDayLog(DateTime.now());
    widget.onChanged();
    _reload();
  }

  Future<void> _deleteHabit(int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete habit?"),
        content: Text("Delete: ${habits[i]}"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    habits.removeAt(i);
    await AppStore.setHabits(habits);

    if (i < log.length) {
      log.removeAt(i);
    }
    await AppStore.setDayLog(DateTime.now(), log);

    widget.onChanged();
    _reload();
  }

  int _maxStreak() {
    if (habits.isEmpty) return 0;

    int best = 0;
    for (int i = 0; i < habits.length; i++) {
      final s = Stats.habitStreak(i, DateTime.now());
      if (s > best) {
        best = s;
      }
    }
    return best;
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(14),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  Widget _miniStat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 26),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = Stats.dayScore(DateTime.now());
    final percent = (score * 100).round();
    final done = log.where((x) => x == 1).length;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text("MASTER"),
          actions: [
            IconButton(onPressed: _addHabit, icon: const Icon(Icons.add)),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _card(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Today Score",
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "$percent%",
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: score,
                              minHeight: 10,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Completed: $done / ${habits.length}",
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _miniStat(
                      Icons.local_fire_department,
                      "${_maxStreak()} d",
                      "Max Streak",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                child: Row(
                  children: [
                    const Icon(Icons.monitor_weight, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: weightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: "Enter weight (kg)",
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF121212),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _saveWeight,
                      child: const Text("Save"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _card(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: habits.length,
                    separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (context, i) {
                      final streak = Stats.habitStreak(i, DateTime.now());
                      final longest = Stats.habitLongestStreak(i);

                      return ListTile(
                        title: Text(habits[i]),
                        subtitle: Text(
                          "Streak: $streak  |  Longest: $longest",
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Checkbox(
                          value: log[i] == 1,
                          onChanged: (v) async {
                            log[i] = (v == true) ? 1 : 0;
                            await AppStore.setDayLog(DateTime.now(), log);
                            widget.onChanged();
                            setState(() {});
                          },
                        ),
                        onLongPress: () => _deleteHabit(i),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Tip: Long press a habit to delete it",
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ==============================
/// HEATMAP
/// ==============================
class HeatmapTab extends StatelessWidget {
  const HeatmapTab({super.key});

  Color colorFor(double v) {
    if (v <= 0.0) return const Color(0xFF141414);
    if (v < 0.25) return const Color(0xFF1F3B2C);
    if (v < 0.50) return const Color(0xFF2F6F4E);
    if (v < 0.75) return const Color(0xFF2FBF73);
    return const Color(0xFF3DFF9A);
  }

  Widget _legendBox(Color c) {
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habits = AppStore.habits();
    final today = DateTime.now();
    final days = List.generate(
      90,
          (i) => today.subtract(Duration(days: 89 - i)),
    );
    final scores = days.map((d) => Stats.dayScore(d)).toList();

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text("Heatmap (90 days)")),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Habits tracked: ${habits.length}",
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.builder(
                    itemCount: 90,
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 18,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemBuilder: (context, i) {
                      final d = days[i];
                      final v = scores[i];

                      return Tooltip(
                        message:
                        "${AppStore.dateKey(d)} • ${(v * 100).round()}%",
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorFor(v),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white10),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Legend",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _legendBox(const Color(0xFF141414)),
                    _legendBox(const Color(0xFF1F3B2C)),
                    _legendBox(const Color(0xFF2F6F4E)),
                    _legendBox(const Color(0xFF2FBF73)),
                    _legendBox(const Color(0xFF3DFF9A)),
                    const SizedBox(width: 10),
                    const Text(
                      "low → high",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ==============================
/// ANALYTICS
/// ==============================
class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habits = AppStore.habits();
    final today = DateTime.now();

    final days = List.generate(
      30,
          (i) => today.subtract(Duration(days: 29 - i)),
    );
    final scores = days.map((d) => Stats.dayScore(d) * 100).toList();

    final weights = AppStore.weightSeries(90);
    final weightList =
    weights.length > 30 ? weights.sublist(weights.length - 30) : weights;

    final rates = List.generate(habits.length, (h) {
      int total = 0;
      int done = 0;

      for (int i = 0; i < 30; i++) {
        final d = today.subtract(Duration(days: i));
        if (!Stats.dayHasAnyLog(d)) continue;
        total++;
        final log = AppStore.getDayLog(d);
        if (log[h] == 1) done++;
      }

      return total == 0 ? 0.0 : done / total;
    });

    final idx = List.generate(habits.length, (i) => i);
    idx.sort((a, b) => rates[b].compareTo(rates[a]));

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text("Analytics")),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _card(
              title: "Daily Productivity (30 days)",
              child: SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minY: 0,
                    maxY: 100,
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        dotData: const FlDotData(show: false),
                        spots: List.generate(
                          scores.length,
                              (i) => FlSpot(i.toDouble(), scores[i]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _card(
              title: "Weight Trend (kg)",
              child: weightList.isEmpty
                  ? const Text(
                "No weight data yet. Enter weight in Today tab.",
                style: TextStyle(color: Colors.white70),
              )
                  : SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        dotData: const FlDotData(show: false),
                        spots: List.generate(
                          weightList.length,
                              (i) => FlSpot(
                            i.toDouble(),
                            weightList[i].value,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _card(
              title: "Habit Leaderboard (Top 10 - 30 days)",
              child: Column(
                children: List.generate(
                  habits.length < 10 ? habits.length : 10,
                      (rank) {
                    final i = idx[rank];
                    final pct = (rates[i] * 100).round();

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              "${rank + 1}",
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          Expanded(child: Text(habits[i])),
                          SizedBox(
                            width: 54,
                            child: Text(
                              "$pct%",
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ==============================
/// REPORTS
/// ==============================
class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key});

  Widget _reportCard(String title, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, height: 1.3),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = ChartBot.fullAnalysisToday();
    final weekly = ChartBot.weeklyReview();

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text("Reports")),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _reportCard("Today Full Analysis", today),
            const SizedBox(height: 12),
            _reportCard("Weekly Review", weekly),
          ],
        ),
      ),
    );
  }
}

/// ==============================
/// BOT
/// ==============================
class BotTab extends StatefulWidget {
  const BotTab({super.key});

  @override
  State<BotTab> createState() => _BotTabState();
}

class _BotTabState extends State<BotTab> {
  final List<Map<String, String>> messages = [
    {
      "role": "bot",
      "text":
      "Hi 👋 I’m MASTER Chart Bot.\nAsk me about your habits and weight and I’ll analyze."
    }
  ];

  final ctrl = TextEditingController();

  void _ask(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      messages.add({"role": "user", "text": text.trim()});
      ctrl.clear();

      final lower = text.toLowerCase();
      if (lower.contains("weekly")) {
        messages.add({"role": "bot", "text": ChartBot.weeklyReview()});
      } else {
        messages.add({"role": "bot", "text": ChartBot.fullAnalysisToday()});
      }
    });
  }

  Widget _chip(String text) {
    return InkWell(
      onTap: () => _ask(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text("Chart Bot")),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip("Full analysis today"),
                  _chip("Weekly review"),
                  _chip("Tomorrow plan"),
                  _chip("Weight trend"),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final m = messages[i];
                  final isUser = m["role"] == "user";

                  return Align(
                    alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 340),
                      decoration: BoxDecoration(
                        color: isUser
                            ? const Color(0xFF2F3B52)
                            : const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        m["text"] ?? "",
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.3,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      decoration: InputDecoration(
                        hintText: "Ask something…",
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF121212),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _ask(ctrl.text),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ==============================
/// SETTINGS
/// ==============================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String reminder = "";

  @override
  void initState() {
    super.initState();
    reminder = AppStore.reminder();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 21, minute: 0),
    );

    if (picked == null) return;

    final hh = picked.hour.toString().padLeft(2, "0");
    final mm = picked.minute.toString().padLeft(2, "0");
    final hhmm = "$hh:$mm";

    await AppStore.setReminder(hhmm);
    await Notifier.scheduleDaily(picked.hour, picked.minute);

    if (!mounted) return;

    setState(() => reminder = hhmm);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Reminder set: $hhmm ✅")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Notifications",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Reminder time: ${reminder.isEmpty ? "Not set" : reminder}",
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.alarm),
                label: const Text("Set reminder time"),
              ),
              const SizedBox(height: 12),
              const Text(
                "Tip: Set reminder at night, for example 21:00, so you never miss updating.",
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}