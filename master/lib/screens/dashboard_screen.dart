import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  final int userId;

  const DashboardScreen({super.key, required this.userId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int todayCompletedCount = 0;
  int todayTotalCount = 0;
  int weeklyPercentage = 0;
  int bestStreak = 0;

  List<dynamic> habits = [];
  List<dynamic> logs = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      final habitsData = await ApiService.getHabits(widget.userId);
      final logsData = await ApiService.getHabitLogsByRange(
        widget.userId,
        DateFormat('yyyy-MM-dd').format(weekStart),
        DateFormat('yyyy-MM-dd').format(weekEnd),
      );

      // Calculations
      int todayCompleted = 0;
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      
      int totalWeeklyCompletions = 0;
      int maxStreak = 0;

      for (var habit in habitsData) {
        if (habit['streak'] != null && habit['streak'] > maxStreak) {
          maxStreak = habit['streak'];
        }
      }

      for (var log in logsData) {
        if (log['status'] == 1) {
          totalWeeklyCompletions++;
          final logDate = log['date'].toString().substring(0, 10);
          if (logDate == todayStr) {
            todayCompleted++;
          }
        }
      }

      int totalPossibleWeekly = habitsData.length * 7;
      int weekPct = totalPossibleWeekly == 0
          ? 0
          : ((totalWeeklyCompletions / totalPossibleWeekly) * 100).toInt();

      if (!mounted) return;

      setState(() {
        habits = habitsData;
        logs = logsData;
        todayCompletedCount = todayCompleted;
        todayTotalCount = habitsData.length;
        weeklyPercentage = weekPct;
        bestStreak = maxStreak;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dashboard Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatCard(
              title: "Today's Habits",
              value: "$todayCompletedCount / $todayTotalCount",
              subtitle: "completed",
              icon: Icons.checklist,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: "Weekly Avg",
                    value: "$weeklyPercentage%",
                    subtitle: "completion rate",
                    icon: Icons.pie_chart,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    title: "Best Streak",
                    value: "$bestStreak",
                    subtitle: "days in a row",
                    icon: Icons.local_fire_department,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "Weekly Progress (Mock Data)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const style = TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          );
                          String text;
                          switch (value.toInt()) {
                            case 0: text = 'Mon'; break;
                            case 1: text = 'Tue'; break;
                            case 2: text = 'Wed'; break;
                            case 3: text = 'Thu'; break;
                            case 4: text = 'Fri'; break;
                            case 5: text = 'Sat'; break;
                            case 6: text = 'Sun'; break;
                            default: text = ''; break;
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 4,
                            child: Text(text, style: style),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    _buildMockBarData(0, 40),
                    _buildMockBarData(1, 60),
                    _buildMockBarData(2, 50),
                    _buildMockBarData(3, 80),
                    _buildMockBarData(4, 90),
                    _buildMockBarData(5, 70),
                    _buildMockBarData(6, weeklyPercentage.toDouble()), // Today's dynamic pct
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildMockBarData(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: Colors.blueAccent,
          width: 16,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [color.withOpacity(0.3), color.withOpacity(0.1)]
              : [color.withOpacity(0.15), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.1 : 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
