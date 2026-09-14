import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const NotesApp());

// ═══════════════════════════════════════════════
// APP ROOT
// ═══════════════════════════════════════════════
class NotesApp extends StatelessWidget {
  const NotesApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

// ═══════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════
class Note {
  final String id;
  String title;
  String body;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'],
        title: j['title'],
        body: j['body'],
        createdAt: DateTime.parse(j['createdAt']),
      );
}

// ═══════════════════════════════════════════════
// STORAGE SERVICE
// ═══════════════════════════════════════════════
class StorageService {
  static const _key = 'notes_v1';

  Future<List<Note>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Note.fromJson(e)).toList();
  }

  Future<void> save(List<Note> notes) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(notes.map((e) => e.toJson()).toList()));
  }
}

// ═══════════════════════════════════════════════
// SCREEN 1: HOME
// ═══════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  List<Note> _notes = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final n = await _storage.load();
    setState(() {
      _notes = n;
      _loading = false;
    });
  }

  Future<void> _persist() => _storage.save(_notes);

  Future<void> _openEditor({Note? existing}) async {
    final result = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (_) => AddNoteScreen(existing: existing)),
    );
    if (result == null) return;
    setState(() {
      if (existing == null) {
        _notes.insert(0, result);
      } else {
        final i = _notes.indexWhere((n) => n.id == existing.id);
        if (i != -1) _notes[i] = result;
      }
    });
    _persist();
  }

  void _delete(String id) {
    setState(() => _notes.removeWhere((n) => n.id == id));
    _persist();
  }

  List<Note> get _filtered {
    if (_query.isEmpty) return _notes;
    final q = _query.toLowerCase();
    return _notes
        .where((n) =>
            n.title.toLowerCase().contains(q) ||
            n.body.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final list = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mere Notes'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.note_alt_outlined,
                            size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _query.isEmpty ? 'Koi note nahi hai' : 'Kuch nahi mila',
                          style: const TextStyle(fontSize: 18),
                        ),
                        if (_query.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text('+ dabakar naya banao'),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) => NoteCard(
                      note: list[i],
                      onTap: () => _openEditor(existing: list[i]),
                      onDelete: () => _delete(list[i].id),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Naya Note'),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// SCREEN 2: ADD / EDIT NOTE
// ═══════════════════════════════════════════════
class AddNoteScreen extends StatefulWidget {
  final Note? existing;
  const AddNoteScreen({super.key, this.existing});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _bodyCtrl = TextEditingController(text: widget.existing?.body ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty && _bodyCtrl.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }
    final note = Note(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    Navigator.pop(context, note);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Note' : 'Naya Note'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
              ),
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: _bodyCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Note likho...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// SCREEN 3: SETTINGS
// ═══════════════════════════════════════════════
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('App version'),
            subtitle: Text('1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Developer'),
            subtitle: Text('Aapka naam'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Clear all data'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Sure?'),
                  content: const Text('Saare notes delete ho jayenge.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                final p = await SharedPreferences.getInstance();
                await p.remove('notes_v1');
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// WIDGET: NOTE CARD
// ═══════════════════════════════════════════════
class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: onTap,
        title: Text(
          note.title.isEmpty ? '(Bina title)' : note.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          note.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
