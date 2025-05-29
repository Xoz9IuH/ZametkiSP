import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeNotifier(),
      child: NotesApp(),
    ),
  );
}

class ThemeNotifier with ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeNotifier() {
    _loadTheme();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }
}

class NotesApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          title: 'Заметочки',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: themeNotifier.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          debugShowCheckedModeBanner: false,
          home: FutureBuilder(
            future: SharedPreferences.getInstance(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final prefs = snapshot.data as SharedPreferences;
              final lastName = prefs.getString('lastName');
              final firstName = prefs.getString('firstName');

              return (lastName == null || lastName.isEmpty || firstName == null || firstName.isEmpty)
                  ? UserDataScreen()
                  : NotesListScreen();
            },
          ),
        );
      },
    );
  }
}

class UserDataScreen extends StatefulWidget {
  @override
  _UserDataScreenState createState() => _UserDataScreenState();
}

class _UserDataScreenState extends State<UserDataScreen> {
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Введите ваши данные')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Фамилия',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Обязательное поле';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'Имя',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Обязательное поле';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _middleNameController,
                decoration: InputDecoration(
                  labelText: 'Отчество (необязательно)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final SharedPreferences prefs = await _prefs;
                    await prefs.setString('lastName', _lastNameController.text);
                    await prefs.setString('firstName', _firstNameController.text);
                    await prefs.setString('middleName', _middleNameController.text);

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NotesListScreen(),
                      ),
                    );
                  }
                },
                child: Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotesListScreen extends StatefulWidget {
  @override
  _NotesListScreenState createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  List<Map<String, dynamic>> notes = [];
  String sortBy = 'dueDate';
  String lastName = '';
  String firstName = '';
  String middleName = '';
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final SharedPreferences prefs = await _prefs;
    setState(() {
      lastName = prefs.getString('lastName') ?? '';
      firstName = prefs.getString('firstName') ?? '';
      middleName = prefs.getString('middleName') ?? '';
      notes = (prefs.getStringList('notes') ?? []).map((note) {
        return Map<String, dynamic>.from(json.decode(note));
      }).toList();
      _sortNotes();
    });
  }

  Future<void> _saveNotes() async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setStringList(
      'notes',
      notes.map((note) => json.encode(note)).toList(),
    );
  }

  void _sortNotes() {
    setState(() {
      if (sortBy == 'dueDate') {
        notes.sort((a, b) {
          if (a['dueDate'] == null && b['dueDate'] == null) return 0;
          if (a['dueDate'] == null) return 1;
          if (b['dueDate'] == null) return -1;
          final dateA = DateFormat('dd.MM.yyyy').parse(a['dueDate']);
          final dateB = DateFormat('dd.MM.yyyy').parse(b['dueDate']);
          return dateA.compareTo(dateB);
        });
      } else {
        notes.sort((a, b) => a['title'].compareTo(b['title']));
      }
    });
  }

  void addNote(Map<String, dynamic> note) {
    setState(() {
      notes.add({
        ...note,
        'userName': '$lastName $firstName${middleName.isNotEmpty ? ' $middleName' : ''}'
      });
      _sortNotes();
      _saveNotes();
    });
  }

  void updateNote(int index, Map<String, dynamic> updatedNote) {
    setState(() {
      notes[index] = {
        ...updatedNote,
        'userName': '$lastName $firstName${middleName.isNotEmpty ? ' $middleName' : ''}'
      };
      _sortNotes();
      _saveNotes();
    });
  }

  void removeNote(int index) {
    setState(() {
      notes.removeAt(index);
      _saveNotes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои заметки'),
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UserProfileScreen()),
              );
              _loadData();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (lastName.isNotEmpty && firstName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Пользователь: $lastName $firstName${middleName.isNotEmpty ? ' $middleName' : ''}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CreateNoteScreen()),
              );
              if (result != null) {
                addNote(result);
              }
            },
            child: const Text('Добавить заметку'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: ListTile(
                    title: Text(note['title']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(note['content']),
                        SizedBox(height: 4),
                        Text('Дата создания: ${note['dateAdded']}'),
                        if (note['dueDate'] != null)
                          Text('Срок выполнения: ${note['dueDate']}'),
                        if (note['extraData'] != null && note['extraData'].isNotEmpty)
                          Text('Дополнительно: ${note['extraData']}'),
                        if (note['userName'] != null && note['userName'].isNotEmpty)
                          Text('Автор: ${note['userName']}'),
                      ],
                    ),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateNoteScreen(
                            existingNote: note,
                            noteIndex: index,
                          ),
                        ),
                      );
                      if (result != null) {
                        updateNote(index, result);
                      }
                    },
                    onLongPress: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Удалить заметку?'),
                            content: Text('Вы уверены, что хотите удалить эту заметку?'),
                            actions: [
                              TextButton(
                                child: Text('Отмена'),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              TextButton(
                                child: Text('Удалить'),
                                onPressed: () {
                                  removeNote(index);
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Заметка удалена')),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class UserProfileScreen extends StatefulWidget {
  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final SharedPreferences prefs = await _prefs;
    setState(() {
      _lastNameController.text = prefs.getString('lastName') ?? '';
      _firstNameController.text = prefs.getString('firstName') ?? '';
      _middleNameController.text = prefs.getString('middleName') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Профиль пользователя')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Фамилия',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Обязательное поле';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'Имя',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Обязательное поле';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _middleNameController,
                decoration: InputDecoration(
                  labelText: 'Отчество (необязательно)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              SwitchListTile(
                title: Text('Тёмная тема'),
                value: themeNotifier.isDarkMode,
                onChanged: (value) {
                  themeNotifier.toggleTheme();
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final SharedPreferences prefs = await _prefs;
                    await prefs.setString('lastName', _lastNameController.text);
                    await prefs.setString('firstName', _firstNameController.text);
                    await prefs.setString('middleName', _middleNameController.text);
                    Navigator.pop(context);
                  }
                },
                child: Text('Сохранить изменения'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateNoteScreen extends StatefulWidget {
  final Map<String, dynamic>? existingNote;
  final int? noteIndex;

  CreateNoteScreen({this.existingNote, this.noteIndex});

  @override
  _CreateNoteScreenState createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();
  final TextEditingController extraDataController = TextEditingController();
  final TextEditingController dueDateController = TextEditingController();
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    if (widget.existingNote != null) {
      titleController.text = widget.existingNote!['title'];
      contentController.text = widget.existingNote!['content'];
      extraDataController.text = widget.existingNote!['extraData'] ?? '';
      if (widget.existingNote!['dueDate'] != null) {
        dueDateController.text = widget.existingNote!['dueDate'];
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        dueDateController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingNote == null ? 'Создать заметку' : 'Редактировать заметку'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Заголовок',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Обязательное поле!';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Содержание',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Обязательное поле!';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: dueDateController,
                decoration: InputDecoration(
                  labelText: 'Срок выполнения',
                  suffixIcon: IconButton(
                    onPressed: () => _selectDate(context),
                    icon: Icon(Icons.calendar_today),
                  ),
                ),
                onTap: () => _selectDate(context),
                readOnly: true,
              ),
              TextFormField(
                controller: extraDataController,
                decoration: const InputDecoration(
                  labelText: 'Дополнительная информация',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final newNote = {
                      'title': titleController.text,
                      'content': contentController.text,
                      'dateAdded': widget.existingNote != null
                          ? widget.existingNote!['dateAdded']
                          : DateFormat('dd.MM.yyyy').format(DateTime.now()),
                      'dueDate': dueDateController.text.isNotEmpty
                          ? dueDateController.text
                          : null,
                      'extraData': extraDataController.text,
                    };
                    Navigator.pop(context, newNote);
                  }
                },
                child: Text(widget.existingNote == null ? 'Сохранить заметку' : 'Обновить заметку'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}