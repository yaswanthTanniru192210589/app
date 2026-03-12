import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class MonthlyCalendarScreen extends StatefulWidget {
  final int userId;
  final int habitId;
  final String habitName;

  const MonthlyCalendarScreen({
    super.key,
    required this.userId,
    required this.habitId,
    required this.habitName,
  });

  @override
  State<MonthlyCalendarScreen> createState() => _MonthlyCalendarScreenState();
}

class _MonthlyCalendarScreenState extends State<MonthlyCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  late DateTime _firstDay;
  late DateTime _lastDay;
  
  Map<DateTime, bool> _completedDays = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _firstDay = DateTime(DateTime.now().year - 1, DateTime.now().month, 1);
    _lastDay = DateTime(DateTime.now().year + 1, DateTime.now().month, 0);
    _loadMonthlyData();
  }

  Future<void> _loadMonthlyData() async {
    setState(() => _isLoading = true);

    try {
      final startDate = DateFormat('yyyy-MM-dd').format(
        DateTime(_focusedDay.year, _focusedDay.month, 1),
      );
      final endDate = DateFormat('yyyy-MM-dd').format(
        DateTime(_focusedDay.year, _focusedDay.month + 1, 0),
      );

      final logs = await ApiService.getHabitLogsByRange(
        widget.userId,
        startDate,
        endDate,
      );

      final Map<DateTime, bool> completed = {};

      for (var log in logs) {
        if (log['habit_id'] == widget.habitId && log['status'] == 1) {
          final String dtStr = log['date'].toString();
          // Extract the Date part if it has time
          final dateStr = dtStr.substring(0, 10);
          final dateObj = DateTime.parse(dateStr);
          // Normalize to midnight UTC for table_calendar
          final normalizedDate = DateTime.utc(dateObj.year, dateObj.month, dateObj.day);
          completed[normalizedDate] = true;
        }
      }

      if (!mounted) return;
      setState(() {
        _completedDays = completed;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading calendar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    _loadMonthlyData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.habitName} - Monthly View'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TableCalendar(
                    firstDay: _firstDay,
                    lastDay: _lastDay,
                    focusedDay: _focusedDay,
                    onPageChanged: _onPageChanged,
                    calendarFormat: CalendarFormat.month,
                    selectedDayPredicate: (day) {
                      return _completedDays.containsKey(DateTime.utc(day.year, day.month, day.day));
                    },
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Month',
                    },
                    calendarBuilders: CalendarBuilders(
                      selectedBuilder: (context, date, events) {
                        return Container(
                          margin: const EdgeInsets.all(6.0),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Text(
                            '${date.day}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      },
                      defaultBuilder: (context, date, events) {
                         return Container(
                          margin: const EdgeInsets.all(6.0),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Text(
                            '${date.day}',
                            style: const TextStyle(color: Colors.black87),
                          ),
                        );
                      },
                      todayBuilder: (context, date, events) {
                        return Container(
                          margin: const EdgeInsets.all(6.0),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            border: Border.all(color: Colors.blue, width: 2),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Text(
                            '${date.day}',
                            style: const TextStyle(color: Colors.blue),
                          ),
                        );
                      }
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
