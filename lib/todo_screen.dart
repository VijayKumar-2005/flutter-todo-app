import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:todo_app/notification_service.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  TodoListScreenState createState() => TodoListScreenState();
}

class TodoListScreenState extends State<TodoListScreen> {
  late Database database;
  List<Map<String, dynamic>> tasks = [];
  final TextEditingController taskController = TextEditingController();
  DateTime? dueDate;
  TimeOfDay? dueTime;

  @override
  void initState() {
    super.initState();
    initDatabase();
  }

  Future<void> initDatabase() async {
    try {
      database = await openDatabase(
        p.join(await getDatabasesPath(), 'todo_database.db'),
        onCreate: (db, version) {
          return db.execute(
            "CREATE TABLE tasks(id INTEGER PRIMARY KEY, task TEXT, dueDate TEXT, dueTime TEXT)",
          );
        },
        version: 1,
      );
      loadTasks();
    } catch (e) {
      print("Error initializing database: $e");
    }
  }

  Future<void> loadTasks() async {
    try {
      final List<Map<String, dynamic>> maps = await database.query('tasks');
      setState(() {
        tasks = maps;
      });
    } catch (e) {
      print("Error loading tasks: $e");
    }
  }

  Future<void> addTask(String task) async {
    if (task.isNotEmpty && dueDate != null && dueTime != null) {
      try {
        final scheduledDateTime = DateTime(
          dueDate!.year,
          dueDate!.month,
          dueDate!.day,
          dueTime!.hour,
          dueTime!.minute,
        );
        final taskMap = {
          'task': task,
          'dueDate': dueDate!.toIso8601String(),
          'dueTime': '${dueTime!.hour}:${dueTime!.minute}'
        };
        int taskId = await database.insert('tasks', taskMap);
        await NotificationService.instance.scheduleNotification(
          id: taskId,
          title: task,
          body: "Don't forget: $task is due at ${dueTime!.format(context)}",
          scheduledDate: scheduledDateTime,
        );
        loadTasks();
        taskController.clear();
        dueDate = null;
        dueTime = null;
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        print("Error adding task: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add task. Please try again.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a date and time for the task.')),
      );
    }
  }

  void deleteTask(int id) async {
    try {
      await database.delete('tasks', where: 'id = ?', whereArgs: [id]);
      loadTasks();
    } catch (e) {
      print("Error deleting task: $e");
    }
  }

  void showAddTaskDialog() {
    showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
      return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add a New Task', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            TextField(
            controller: taskController,
            decoration: InputDecoration(hintText: 'Enter task here'),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: dialogContext,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2101),
              );
              if (picked != null) {
                setState(() => dueDate = picked);
              }
            },
            child: Text('Select Due Date'),
          ),
          ElevatedButton(
          onPressed: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: dialogContext,
          initialTime: TimeOfDay.now(),
        );
        if (picked != null) {
          setState(() => dueTime = picked);
        }
      },
            child: Text('Select Due Time'),
          ),
              if (dueDate != null && dueTime != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Scheduled for: ${dueDate!.toLocal().toString().split(' ')[0]} at ${dueTime!.format(context)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ),
            ],
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => addTask(taskController.text),
            child: Text('Add'),
          ),
        ],
      );
        },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      appBar: AppBar(
        title: Text('Todo List', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.grey[900],
      ),
      body: tasks.isEmpty
          ? Center(
        child: Text(
          'No tasks yet. Add a new task!',
          style: TextStyle(fontSize: 18, color: Colors.grey[400]),
        ),
      )
          : ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          final dueDate = DateTime.parse(task['dueDate']);
          final dueTime = task['dueTime'];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            color: Colors.grey[800],
            child: ListTile(
              title: Text(
                task['task'],
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Due: ${dueDate.toLocal().toString().split(' ')[0]} at $dueTime',
                style: TextStyle(color: Colors.grey[400]),
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => deleteTask(task['id']),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddTaskDialog,
        backgroundColor: Colors.blue,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}