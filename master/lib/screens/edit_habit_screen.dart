import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EditHabitScreen extends StatefulWidget {
  final int habitId;
  final String initialName;
  final String initialDescription;

  const EditHabitScreen({
    super.key,
    required this.habitId,
    required this.initialName,
    required this.initialDescription,
  });

  @override
  State<EditHabitScreen> createState() => _EditHabitScreenState();
}

class _EditHabitScreenState extends State<EditHabitScreen> {
  late TextEditingController habitNameController;
  late TextEditingController descriptionController;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    habitNameController = TextEditingController(text: widget.initialName);
    descriptionController = TextEditingController(text: widget.initialDescription);
  }

  Future<void> updateHabit() async {
    final habitName = habitNameController.text.trim();
    final description = descriptionController.text.trim();

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
      await ApiService.updateHabit(
        widget.habitId,
        habitName,
        description,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update habit: $e')),
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
        title: const Text('Edit Habit'),
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : updateHabit,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
