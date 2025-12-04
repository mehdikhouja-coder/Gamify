import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';

class TaskEditorPage extends ConsumerStatefulWidget {
  const TaskEditorPage({super.key});

  @override
  ConsumerState<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends ConsumerState<TaskEditorPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  String _category = 'Personal';
  String _difficulty = 'Easy';
  bool _isHabit = false;
  DateTime? _deadline;

  int _xpForDifficulty(String d) {
    switch (d) {
      case 'Easy':
        return 10;
      case 'Medium':
        return 20;
      case 'Hard':
        return 40;
      default:
        return 10;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Task')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Title'), validator: (v) => (v == null || v.isEmpty) ? 'Enter a title' : null),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: ['Study', 'Fitness', 'Personal', 'Work']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? 'Personal'),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _difficulty,
                items: ['Easy', 'Medium', 'Hard']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _difficulty = v ?? 'Easy'),
                decoration: const InputDecoration(labelText: 'Difficulty'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(value: _isHabit, onChanged: (v) => setState(() => _isHabit = v), title: const Text('Is Habit')),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_deadline == null ? 'No Deadline' : 'Deadline: ${_deadline!.month}/${_deadline!.day}/${_deadline!.year}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_deadline != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _deadline = null),
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _deadline ?? DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _deadline = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (!_form.currentState!.validate()) return;
                    final id = const Uuid().v4();
                    final t = Task(
                      id: id,
                      title: _title.text.trim(),
                      category: _category,
                      xp: _xpForDifficulty(_difficulty),
                      isHabit: _isHabit,
                      frequency: _isHabit ? 'daily' : '',
                      deadline: _deadline,
                    );
                    // capture navigator before async gap to avoid using context across await
                    final navigator = Navigator.of(context);
                    await ref.read(tasksProvider.notifier).addTask(t);
                    if (!mounted) return;
                    navigator.pop();
                  },
                  child: const Text('Save Task'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
