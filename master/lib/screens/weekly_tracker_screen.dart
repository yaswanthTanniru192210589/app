import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'create_habit_screen.dart';
import 'monthly_calendar_screen.dart';
import 'edit_habit_screen.dart';

class WeeklyTrackerScreen extends StatefulWidget {
  final int userId;

  const WeeklyTrackerScreen({super.key, required this.userId});

  @override
  State<WeeklyTrackerScreen> createState() => _WeeklyTrackerScreenState();
}

class _WeeklyTrackerScreenState extends State<WeeklyTrackerScreen> {
  List<dynamic> habits = [];
  List<dynamic> logs = [];
  bool isLoading = true;

  late DateTime weekStart;
  late DateTime weekEnd;
  late List<DateTime> weekDays;

  @override
  void initState() {
    super.initState();
    _setCurrentWeek();
    loadData();
  }

  void _setCurrentWeek() {
    final now = DateTime.now();
    weekStart = now.subtract(Duration(days: now.weekday - 1));
    weekEnd = weekStart.add(const Duration(days: 6));
    weekDays = List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );
  }

  Future<void> loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final habitsData = await ApiService.getHabits(widget.userId);
      final logsData = await ApiService.getHabitLogsByRange(
        widget.userId,
        DateFormat('yyyy-MM-dd').format(weekStart),
        DateFormat('yyyy-MM-dd').format(weekEnd),
      );

      if (!mounted) return;

      setState(() {
        habits = habitsData;
        logs = logsData;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  bool isHabitCompleted(int habitId, DateTime day) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(day);

    return logs.any(
      (log) =>
          log['habit_id'] == habitId &&
          log['date'].toString().startsWith(formattedDate) &&
          log['status'] == 1,
    );
  }

  Future<void> toggleHabit(int habitId, DateTime day) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(day);
    final currentlyCompleted = isHabitCompleted(habitId, day);

    try {
      await ApiService.logHabit(
        userId: widget.userId,
        habitId: habitId,
        date: formattedDate,
        status: currentlyCompleted ? 0 : 1,
      );

      await loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update habit: $e')),
      );
    }
  }

  Future<void> deleteHabit(int habitId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Habit'),
          content: const Text('Are you sure you want to delete this habit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteHabit(habitId);
      await loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Habit deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete habit: $e')),
      );
    }
  }

  void previousWeek() {
    setState(() {
      weekStart = weekStart.subtract(const Duration(days: 7));
      weekEnd = weekStart.add(const Duration(days: 6));
      weekDays = List.generate(
        7,
        (index) => weekStart.add(Duration(days: index)),
      );
    });
    loadData();
  }

  void nextWeek() {
    setState(() {
      weekStart = weekStart.add(const Duration(days: 7));
      weekEnd = weekStart.add(const Duration(days: 6));
      weekDays = List.generate(
        7,
        (index) => weekStart.add(Duration(days: index)),
      );
    });
    loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateHabitScreen(userId: widget.userId),
            ),
          );

          if (result == true) {
            loadData();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : habits.isEmpty
              ? const Center(child: Text('No habits found'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: previousWeek,
                              icon: const Icon(Icons.arrow_back),
                            ),
                            Text(
                              '${DateFormat('dd MMM').format(weekStart)} - ${DateFormat('dd MMM yyyy').format(weekEnd)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: nextWeek,
                              icon: const Icon(Icons.arrow_forward),
                            ),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 760,
                          child: Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 180,
                                      child: Text(
                                        'Habit',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    ...weekDays.map((day) {
                                      return Expanded(
                                        child: Column(
                                          children: [
                                            Text(
                                              DateFormat('E').format(day),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              DateFormat('d').format(day),
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              const Divider(),
                              Builder(
                                                  builder: (context) {
                                                    // Group habits by category
                                                    final Map<String, List<dynamic>> habitsByCategory = {};
                                                    for (var habit in habits) {
                                                      final category = habit['category'] ?? 'Uncategorized';
                                                      if (!habitsByCategory.containsKey(category)) {
                                                        habitsByCategory[category] = [];
                                                      }
                                                      habitsByCategory[category]!.add(habit);
                                                    }
                                                    
                                                    final sortedCategories = habitsByCategory.keys.toList()..sort();
                                                    
                                                    return Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: sortedCategories.map((category) {
                                                        final categoryHabits = habitsByCategory[category]!;
                                                        
                                                        return Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Padding(
                                                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                                              child: Text(
                                                                category,
                                                                style: const TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: Colors.blueGrey,
                                                                ),
                                                              ),
                                                            ),
                                                            ListView.builder(
                                                              itemCount: categoryHabits.length,
                                                              shrinkWrap: true,
                                                              physics: const NeverScrollableScrollPhysics(),
                                                              itemBuilder: (context, index) {
                                                                final habit = categoryHabits[index];
                                                                final int habitId = habit['id'];

                                                                return Padding(
                                                                  padding: const EdgeInsets.symmetric(
                                                                    horizontal: 8,
                                                                    vertical: 6,
                                                                  ),
                                                                  child: Container(
                                                                    padding: const EdgeInsets.all(12),
                                                                    decoration: BoxDecoration(
                                                                      color: Theme.of(context).cardColor,
                                                                      borderRadius: BorderRadius.circular(16),
                                                                      boxShadow: [
                                                                        BoxShadow(
                                                                          blurRadius: 8,
                                                                          color: Theme.of(context).shadowColor.withOpacity(0.1),
                                                                          offset: const Offset(0, 4),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    child: Row(
                                                                      children: [
                                          SizedBox(
                                            width: 180,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) => MonthlyCalendarScreen(
                                                            userId: widget.userId,
                                                            habitId: habitId,
                                                            habitName: habit['habit_name'] ?? 'Unnamed Habit',
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          habit['habit_name'] ??
                                                              'Unnamed Habit',
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Theme.of(context).colorScheme.primary, // Themed clickable color
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          habit['description'] ??
                                                              '',
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                                                          ),
                                                        ),
                                                        if (habit['streak'] != null && habit['streak'] > 0)
                                                          Padding(
                                                            padding: const EdgeInsets.only(top: 4.0),
                                                          child: Text(
                                                            '🔥 ${habit['streak']} day streak',
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.deepOrange,
                                                            ),
                                                          ),
                                                        ),
                                                          Builder(
                                                        builder: (context) {
                                                          int completedDays = 0;
                                                          for (var day in weekDays) {
                                                            if (isHabitCompleted(habitId, day)) {
                                                              completedDays++;
                                                            }
                                                          }
                                                          final percentage = ((completedDays / 7) * 100).toInt();
                                                          return Padding(
                                                            padding: const EdgeInsets.only(top: 4.0),
                                                            child: Text(
                                                              'Week Progress: $completedDays / 7 ($percentage%)',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w500,
                                                                color: Theme.of(context).colorScheme.secondary,
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () async {
                                                    final result = await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => EditHabitScreen(
                                                          habitId: habitId,
                                                          initialName: habit['habit_name'] ?? '',
                                                          initialDescription: habit['description'] ?? '',
                                                        ),
                                                      ),
                                                    );
                                                    if (result == true) {
                                                      loadData();
                                                    }
                                                  },
                                                  icon: const Icon(
                                                    Icons.edit,
                                                    color: Colors.blue,
                                                    size: 20,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  onPressed: () =>
                                                      deleteHabit(habitId),
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                    size: 20,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                              ],
                                            ),
                                          ),
                                          ...weekDays.map((day) {
                                            final completed =
                                                isHabitCompleted(habitId, day);

                                            return Expanded(
                                              child: GestureDetector(
                                                onTap: () =>
                                                    toggleHabit(habitId, day),
                                                child: Container(
                                                  margin:
                                                      const EdgeInsets.all(4),
                                                  height: 42,
                                                  decoration: BoxDecoration(
                                                    color: completed
                                                        ? Colors.green
                                                        : Colors.grey.shade300,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      10,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    completed
                                                        ? Icons.check
                                                        : Icons.close,
                                                    color: completed
                                                        ? Colors.white
                                                        : Colors.black54,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}