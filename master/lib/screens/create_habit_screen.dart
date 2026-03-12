import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CreateHabitScreen extends StatefulWidget {
  final int userId;

  const CreateHabitScreen({super.key, required this.userId});

  @override
  State<CreateHabitScreen> createState() => _CreateHabitScreenState();
}

class _CreateHabitScreenState extends State<CreateHabitScreen> {
  final TextEditingController habitNameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  
  String selectedCategory = 'Uncategorized';
  final List<String> categories = ['Health', 'Fitness', 'Learning', 'Mindfulness', 'Productivity', 'Uncategorized'];

  bool isLoading = false;

  Future<void> saveHabit() async {
    final habitName = habitNameController.text.trim();
    final description = descriptionController.text.trim();
    final category = selectedCategory;

    if (habitName.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await ApiService.createHabit(
        userId: widget.userId,
        habitName: habitName,
        description: description,
        category: category,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create habit: $e')),
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
  void dispose() {
    habitNameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Habit'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: habitNameController,
                decoration: const InputDecoration(
                  labelText: 'Habit Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    if (newValue != null) {
                      selectedCategory = newValue;
                    }
                  });
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : saveHabit,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Save Habit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}