import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// APP BRAND (Icon theme integration)
// ============================================================
class AppBrand {
  static const primary = Color(0xFF007ACC);    // VS Code blue
  static const secondary = Color(0xFF4EC9B0);  // Cyan accent
  static const background = Color(0xFF181818); // Dark bg
  static const surface = Color(0xFF1E1E1E);    // Card surface
  static const iconBackground = "#181818";     // Adaptive icon bg
  static const iconForeground = "#007ACC";     // Adaptive icon fg
}

// ============================================================
// COLORS (Tailwind config se exact)
// ============================================================
class VS {
  static const bg = Color(0xFF181818);
  static const activityBar = Color(0xFF141414);
  static const sidebar = Color(0xFF1E1E1E);
  static const editor = Color(0xFF181818);
  static const tabActive = Color(0xFF1E1E1E);
  static const tabInactive = Color(0xFF141414);
  static const border = Color(0xFF282828);
  static const hover = Color(0xFF2A2D2E);
  static const selected = Color(0xFF04395E);
  static const accent = Color(0xFF007ACC);
  static const accentHover = Color(0xFF0062A3);
  static const danger = Color(0xFFF44747);
  static const text = Color(0xFFD4D4D4);
  static const muted = Color(0xFF858585);
  static const card = Color(0xFF222222);
  static const blueFolder = Color(0xFF519ABA);
}

// Syntax highlight tokens
class Tok {
  static const keyword = Color(0xFFC586C0);
  static const type = Color(0xFF4EC9B0);
  static const func = Color(0xFFDCDCA6);
  static const string = Color(0xFFCE9178);
  static const number = Color(0xFFB5CEA8);
  static const comment = Color(0xFF6A9955);
  static const annotation = Color(0xFF9CDCFE);
}

// ============================================================
// DATA MODELS
// ============================================================
class FileNode {
  String id;
  String name;
  bool isFolder;
  String? parentId;
  bool isOpen;
  String? content;

  FileNode({
    required this.id,
    required this.name,
    required this.isFolder,
    this.parentId,
    this.isOpen = false,
    this.content,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isFolder': isFolder,
        'parentId': parentId,
        'isOpen': isOpen,
        'content': content,
      };

  factory FileNode.fromJson(Map<String, dynamic> j) => FileNode(
        id: j['id'],
        name: j['name'],
        isFolder: j['isFolder'] ?? false,
        parentId: j['parentId'],
        isOpen: j['isOpen'] ?? false,
        content: j['content'],
      );
}

class EditorSettings {
  int fontSize;
  int tabSize;
  bool lineNumbers;
  bool wordWrap;
  bool autoSave;

  EditorSettings({
    this.fontSize = 13,
    this.tabSize = 2,
    this.lineNumbers = true,
    this.wordWrap = false,
    this.autoSave = true,
  });

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'tabSize': tabSize,
        'lineNumbers': lineNumbers,
        'wordWrap': wordWrap,
        'autoSave': autoSave,
      };

  factory EditorSettings.fromJson(Map<String, dynamic> j) => EditorSettings(
        fontSize: j['fontSize'] ?? 13,
        tabSize: j['tabSize'] ?? 2,
        lineNumbers: j['lineNumbers'] ?? true,
        wordWrap: j['wordWrap'] ?? false,
        autoSave: j['autoSave'] ?? true,
      );
}

class ProjectSnapshot {
  String id;
  String name;
  int savedAt;
  int fileCount;
  List<FileNode> nodes;
  List<String> openTabs;
  String? activeTabId;

  ProjectSnapshot({
    required this.id,
    required this.name,
    required this.savedAt,
    required this.fileCount,
    required this.nodes,
    required this.openTabs,
    this.activeTabId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'savedAt': savedAt,
        'fileCount': fileCount,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'openTabs': openTabs,
        'activeTabId': activeTabId,
      };

  factory ProjectSnapshot.fromJson(Map<String, dynamic> j) => ProjectSnapshot(
        id: j['id'],
        name: j['name'],
        savedAt: j['savedAt'],
        fileCount: j['fileCount'] ?? 0,
        nodes: (j['nodes'] as List).map((e) => FileNode.fromJson(e)).toList(),
        openTabs: List<String>.from(j['openTabs'] ?? []),
        activeTabId: j['activeTabId'],
      );
}

// ============================================================
// MAIN APP
// ============================================================
void main() {
  runApp(const IDEApp());
}

class IDEApp extends StatelessWidget {
  const IDEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile Native IDE Engine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppBrand.background,
        fontFamily: 'monospace',
        colorScheme: const ColorScheme.dark(
          primary: AppBrand.primary,
          secondary: AppBrand.secondary,
          surface: AppBrand.surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppBrand.surface,
          foregroundColor: Colors.white,
        ),
      ),
      home: const IDEScreen(),
    );
  }
}

// ============================================================
// MAIN SCREEN
// ============================================================
class IDEScreen extends StatefulWidget {
  const IDEScreen({super.key});

  @override
  State<IDEScreen> createState() => IDEScreenState();
}

class IDEScreenState extends State<IDEScreen> {
  static const String _storageKey = 'DEV_IDE_WORKSPACE_V10';
  static const String _historyKey = 'DEV_IDE_PROJECT_HISTORY_V1';
  static const int _historyLimit = 3;

  // -------- STATE --------
  String? projectName;
  EditorSettings settings = EditorSettings();
  List<FileNode> nodes = [];
  List<String> openTabs = [];
  String? activeTabId;

  // -------- FIND STATE --------
  bool findMatchCase = false;
  bool findWholeWord = false;
  List<Map<String, int>> findMatches = [];
  int currentMatchIndex = -1;

  // -------- UI STATE --------
  bool sidebarOpen = false;
  bool railCollapsed = false;
  bool findBarVisible = false;
  bool settingsOpen = false;
  bool welcomeVisible = true;
  String activeSideTab = 'explorer';

  // -------- CONTEXT SHEET / DIALOG --------
  String? contextNodeId;
  bool contextSheetVisible = false;
  bool dialogVisible = false;
  String dialogTitle = '';
  String dialogSubtitle = '';
  String dialogInitial = '';
  Function(String)? dialogCallback;

  // -------- PROJECT HISTORY --------
  bool historyVisible = false;
  List<ProjectSnapshot> projectHistory = [];
  String historyQuery = '';
  int historySelected = 0;
  List<Map<String, dynamic>> historyRows = [];

  // -------- EDITOR --------
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  final TextEditingController _dialogController = TextEditingController();
  final TextEditingController _historySearchController = TextEditingController();
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _gutterScroll = ScrollController();
  final FocusNode _codeFocus = FocusNode();

  String saveStatus = 'Synced';
  String caretPos = 'Ln 1, Col 1';

  @override
  void initState() {
    super.initState();
    _loadState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initUI());
  }

  void _initUI() {
    setState(() {
      _applyStyles();
      _updateWelcomeVisibility();
    });
  }

  // ============================================================
  // PERSISTENCE
  // ============================================================
  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final j = jsonDecode(raw);
        projectName = j['projectName'];
        settings = EditorSettings.fromJson(j['settings'] ?? {});
        nodes = (j['nodes'] as List? ?? [])
            .map((e) => FileNode.fromJson(e))
            .toList();
        openTabs = List<String>.from(j['openTabs'] ?? []);
        activeTabId = j['activeTabId'];
      } catch (_) {}
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        projectHistory =
            list.map((e) => ProjectSnapshot.fromJson(e)).toList();
      } catch (_) {}
    }
  }

  Future<bool> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'projectName': projectName,
        'settings': settings.toJson(),
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'openTabs': openTabs,
        'activeTabId': activeTabId,
      };
      await prefs.setString(_storageKey, jsonEncode(data));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = projectHistory.take(_historyLimit).toList();
    await prefs.setString(
        _historyKey, jsonEncode(list.map((p) => p.toJson()).toList()));
  }

  void _recordProjectInHistory() {
    if (projectName == null || nodes.isEmpty) return;
    projectHistory.removeWhere((p) => p.name == projectName);
    projectHistory.insert(
      0,
      ProjectSnapshot(
        id: 'proj_${_rand(9)}',
        name: projectName!,
        savedAt: DateTime.now().millisecondsSinceEpoch,
        fileCount: nodes.where((n) => !n.isFolder).length,
        nodes: List.from(nodes),
        openTabs: List.from(openTabs),
        activeTabId: activeTabId,
      ),
    );
    projectHistory = projectHistory.take(_historyLimit).toList();
    _saveHistory();
  }

  String _rand(int len) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random();
    return String.fromCharCodes(Iterable.generate(
        len, (_) => chars.codeUnitAt(r.nextInt(chars.length))));
  }

  // ============================================================
  // STYLES
  // ============================================================
  void _applyStyles() {
    // Settings apply directly in build
  }

  void _updateWelcomeVisibility() {
    welcomeVisible = nodes.isEmpty;
  }

  // ============================================================
  // FILE OPERATIONS
  // ============================================================
  Future<void> _triggerFolderOpen() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result == null) return;

      final dir = Directory(result);
      final dirName = dir.path.split(Platform.pathSeparator).last;

      final newNodes = <FileNode>[];
      await _readDirectory(dir, null, newNodes);

      setState(() {
        projectName = dirName;
        nodes = newNodes;
        openTabs = [];
        activeTabId = null;
      });

      final firstFile = nodes.firstWhere(
        (n) => !n.isFolder,
        orElse: () => FileNode(id: '', name: '', isFolder: true),
      );
      if (firstFile.id.isNotEmpty) {
        openTabs = [firstFile.id];
        activeTabId = firstFile.id;
      }

      await _persistState();
      _recordProjectInHistory();
      _renderAll();
      _closeDrawer();
    } catch (e) {
      debugPrint('Folder open error: $e');
    }
  }

  Future<void> _readDirectory(
      Directory dir, String? parentId, List<FileNode> out) async {
    try {
      final entries = dir.listSync();
      for (final entity in entries) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.startsWith('.')) continue;
        final id = 'id_${_rand(9)}';
        if (entity is Directory) {
          out.add(FileNode(
            id: id,
            name: name,
            isFolder: true,
            parentId: parentId,
            isOpen: false,
          ));
          await _readDirectory(entity, id, out);
        } else if (entity is File) {
          String content = '';
          try {
            final bytes = await entity.readAsBytes();
            if (bytes.length < 1024 * 1024) {
              content = utf8.decode(bytes, allowMalformed: true);
            } else {
              content = '// File too large to display';
            }
          } catch (_) {}
          out.add(FileNode(
            id: id,
            name: name,
            isFolder: false,
            parentId: parentId,
            content: content,
          ));
        }
      }
    } catch (_) {}
  }

  void _openFile(String id) {
    if (!openTabs.contains(id)) openTabs.add(id);
    activeTabId = id;
    _persistState();
    _mountEditor();
    _renderAll();
  }

  void _closeTab(String id) {
    openTabs.removeWhere((t) => t == id);
    if (activeTabId == id) {
      activeTabId = openTabs.isNotEmpty ? openTabs.last : null;
    }
    _persistState();
    _mountEditor();
    _renderAll();
  }

  void _renderAll() {
    setState(() {});
  }

  void _mountEditor() {
    final active = nodes.firstWhere(
      (n) => n.id == activeTabId,
      orElse: () => FileNode(id: '', name: '', isFolder: true),
    );
    if (active.id.isNotEmpty) {
      _codeController.text = active.content ?? '';
    } else {
      _codeController.text = '';
    }
    _updateCaretStatus();
    _refreshFindMatchesQuiet();
  }

  void _handleEditorInput() {
    final active = nodes.firstWhere(
      (n) => n.id == activeTabId,
      orElse: () => FileNode(id: '', name: '', isFolder: true),
    );
    if (active.id.isNotEmpty) {
      active.content = _codeController.text;
      setState(() => saveStatus = 'Modified');
      _persistState().then((ok) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() => saveStatus = ok ? 'Synced' : 'Save Failed');
          }
        });
      });
    }
    _refreshFindMatchesQuiet();
    _updateCaretStatus();
  }

  void _updateCaretStatus() {
    final sel = _codeController.selection;
    final text = _codeController.text.substring(
      0,
      sel.baseOffset.clamp(0, _codeController.text.length),
    );
    final lines = text.split('\n');
    final row = lines.length;
    final col = lines.last.length + 1;
    setState(() => caretPos = 'Ln $row, Col $col');
  }

  // ============================================================
  // SYNTAX HIGHLIGHTING
  // ============================================================
  String _getLanguage(String name) {
    if (name.endsWith('.dart')) return 'Dart';
    if (name.endsWith('.yaml') || name.endsWith('.yml')) return 'YAML';
    if (name.endsWith('.js')) return 'JavaScript';
    if (name.endsWith('.json')) return 'JSON';
    return 'Plain Text';
  }

  List<TextSpan> _highlightCode(
      String code, String lang, double fontSize, double lineHeight) {
    final baseStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      height: lineHeight / fontSize,
      color: VS.text,
      letterSpacing: 0,
    );

    if (lang != 'Dart' && lang != 'YAML') {
      return [TextSpan(text: code.isEmpty ? ' ' : code, style: baseStyle)];
    }

    final tokens = <_Token>[];
    final patterns = <_Pattern>[];

    if (lang == 'Dart') {
      patterns.addAll([
        _Pattern(RegExp(r'//[^\n]*'), Tok.comment),
        _Pattern(RegExp(r'/\*[\s\S]*?\*/'), Tok.comment),
        _Pattern(
            RegExp(r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\""), Tok.string),
        _Pattern(RegExp(r'@[a-zA-Z_]\w*'), Tok.annotation),
        _Pattern(
            RegExp(
                r'\b(?:import|export|class|extends|implements|with|var|final|const|late|required|void|return|if|else|switch|case|break|for|while|do|in|is|as|true|false|null|async|await|yield|super|this|new|get|set|static|factory)\b'),
            Tok.keyword),
        _Pattern(
            RegExp(
                r'\b(?:int|double|num|bool|String|List|Map|Set|Future|Stream|Widget|StatelessWidget|StatefulWidget|BuildContext|Color|Colors|MaterialApp|Scaffold|AppBar|Text|Container|Center|Column|Row|Padding|EdgeInsets|TextStyle|ThemeData)\b'),
            Tok.type),
        _Pattern(RegExp(r'\b[a-zA-Z_]\w*(?=\()'), Tok.func),
        _Pattern(RegExp(r'\b\d+(?:\.\d+)?\b'), Tok.number),
      ]);
    } else {
      patterns.addAll([
        _Pattern(RegExp(r'#.*$', multiLine: true), Tok.comment),
        _Pattern(RegExp(r'[a-zA-Z0-9_\-]+(?=\s*:)'), Tok.keyword),
        _Pattern(RegExp(r"'[^']*'|\"[^\"]*\""), Tok.string),
        _Pattern(RegExp(r'\b\d+\b'), Tok.number),
      ]);
    }

    for (final p in patterns) {
      for (final m in p.regex.allMatches(code)) {
        tokens.add(_Token(m.start, m.end, p.color));
      }
    }

    tokens.sort((a, b) => a.start.compareTo(b.start));

    final finalTokens = <_Token>[];
    int lastEnd = 0;
    for (final t in tokens) {
      if (t.start >= lastEnd) {
        finalTokens.add(t);
        lastEnd = t.end;
      }
    }

    final spans = <TextSpan>[];
    int cursor = 0;
    for (final t in finalTokens) {
      if (t.start > cursor) {
        spans.add(TextSpan(
            text: code.substring(cursor, t.start), style: baseStyle));
      }
      spans.add(TextSpan(
        text: code.substring(t.start, t.end),
        style: baseStyle.copyWith(color: t.color),
      ));
      cursor = t.end;
    }
    if (cursor < code.length) {
      spans.add(TextSpan(text: code.substring(cursor), style: baseStyle));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: ' ', style: baseStyle));
    }
    return spans;
  }

  // ============================================================
  // FIND & REPLACE
  // ============================================================
  void _runFindSearch() {
    final query = _findController.text;
    if (query.isEmpty) {
      setState(() {
        findMatches = [];
        currentMatchIndex = -1;
      });
      return;
    }
    final text = _codeController.text;
    final pattern = _buildFindRegex(query);
    final matches = <Map<String, int>>[];
    for (final m in pattern.allMatches(text)) {
      matches.add({'start': m.start, 'end': m.end});
    }
    setState(() {
      findMatches = matches;
      currentMatchIndex = -1;
    });
    if (matches.isNotEmpty) {
      _goToFindMatch(0, false);
    }
  }

  RegExp _buildFindRegex(String query) {
    final escaped = RegExp.escape(query);
    final pattern = findWholeWord ? '\\b$escaped\\b' : escaped;
    return RegExp(pattern, caseSensitive: findMatchCase);
  }

  void _refreshFindMatchesQuiet() {
    if (!findBarVisible) return;
    final query = _findController.text;
    if (query.isEmpty) {
      setState(() {
        findMatches = [];
        currentMatchIndex = -1;
      });
      return;
    }
    final text = _codeController.text;
    final pattern = _buildFindRegex(query);
    final matches = <Map<String, int>>[];
    for (final m in pattern.allMatches(text)) {
      matches.add({'start': m.start, 'end': m.end});
    }
    setState(() {
      findMatches = matches;
      if (currentMatchIndex >= matches.length) {
        currentMatchIndex = matches.isNotEmpty ? matches.length - 1 : -1;
      }
    });
  }

  void _goToFindMatch(int index, bool focus) {
    if (findMatches.isEmpty) return;
    final n = findMatches.length;
    index = ((index % n) + n) % n;
    final m = findMatches[index];
    _codeController.selection = TextSelection(
      baseOffset: m['start']!,
      extentOffset: m['end']!,
    );
    if (focus) _codeFocus.requestFocus();
    setState(() => currentMatchIndex = index);
    _updateCaretStatus();
  }

  void _findNext() {
    if (findMatches.isEmpty) {
      _runFindSearch();
      return;
    }
    _goToFindMatch(currentMatchIndex + 1, true);
  }

  void _findPrev() {
    if (findMatches.isEmpty) {
      _runFindSearch();
      return;
    }
    _goToFindMatch(currentMatchIndex - 1, true);
  }

  void _replaceCurrentMatch() {
    if (findMatches.isEmpty || currentMatchIndex < 0) return;
    final m = findMatches[currentMatchIndex];
    final val = _codeController.text;
    final replacement = _replaceController.text;
    final newText = val.substring(0, m['start']!) +
        replacement +
        val.substring(m['end']!);
    _codeController.text = newText;
    _codeController.selection =
        TextSelection.collapsed(offset: m['start']! + replacement.length);
    _handleEditorInput();
    _runFindSearch();
  }

  void _replaceAllMatches() {
    final query = _findController.text;
    if (query.isEmpty) return;
    final pattern = _buildFindRegex(query);
    final newText =
        _codeController.text.replaceAll(pattern, _replaceController.text);
    _codeController.text = newText;
    _handleEditorInput();
    _runFindSearch();
  }

  // ============================================================
  // DRAWER / SETTINGS
  // ============================================================
  void _openDrawer() => setState(() => sidebarOpen = true);
  void _closeDrawer() => setState(() => sidebarOpen = false);

  void _switchActivityTab(String tab) {
    setState(() => activeSideTab = tab);
    _openDrawer();
  }

  // ============================================================
  // CONTEXT SHEET / DIALOG
  // ============================================================
  String _getFullPath(String? nodeId) {
    if (nodeId == null) return '/';
    final node = nodes.firstWhere(
      (n) => n.id == nodeId,
      orElse: () => FileNode(id: '', name: '', isFolder: false),
    );
    if (node.id.isEmpty) return '/';
    if (node.parentId == null) return '/${node.name}';
    return '${_getFullPath(node.parentId)}/${node.name}';
  }

  void _openActionSheet(String nodeId) {
    setState(() {
      contextNodeId = nodeId;
      contextSheetVisible = true;
    });
  }

  void _closeActionSheet() {
    setState(() => contextSheetVisible = false);
  }

  void _openDialog(
      String title, String subtitle, String initial, Function(String) cb) {
    _closeActionSheet();
    setState(() {
      dialogTitle = title;
      dialogSubtitle = subtitle;
      dialogInitial = initial;
      _dialogController.text = initial;
      dialogCallback = cb;
      dialogVisible = true;
    });
  }

  void _closeDialog() {
    setState(() {
      dialogVisible = false;
      dialogCallback = null;
    });
  }

  void _confirmDialog() {
    final val = _dialogController.text.trim();
    if (val.isNotEmpty && dialogCallback != null) {
      dialogCallback!(val);
    }
    _closeDialog();
  }

  // ============================================================
  // PROJECT HISTORY
  // ============================================================
  void _openHistory() {
    setState(() {
      historyVisible = true;
      historyQuery = '';
      _historySearchController.text = '';
      historySelected = 0;
      _buildHistoryRows();
    });
  }

  void _closeHistory() => setState(() => historyVisible = false);

  void _buildHistoryRows() {
    final q = historyQuery.toLowerCase();
    historyRows = projectHistory
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .map((p) => {'type': 'project', 'project': p})
        .toList();
    historyRows.add({'type': 'open-folder'});
    if (projectHistory.isNotEmpty) {
      historyRows.add({'type': 'clear-history'});
    }
  }

  void _openProjectFromHistory(String id) {
    final proj = projectHistory.firstWhere(
      (p) => p.id == id,
      orElse: () => ProjectSnapshot(
        id: '',
        name: '',
        savedAt: 0,
        fileCount: 0,
        nodes: [],
        openTabs: [],
      ),
    );
    if (proj.id.isEmpty) return;
    setState(() {
      projectName = proj.name;
      nodes = proj.nodes;
      openTabs = proj.openTabs;
      activeTabId = proj.activeTabId;
      _closeHistory();
      _closeDrawer();
    });
    _persistState();
    _mountEditor();
  }

  void _activateHistoryRow(int idx) {
    if (idx < 0 || idx >= historyRows.length) return;
    final r = historyRows[idx];
    if (r['type'] == 'project') {
      _openProjectFromHistory((r['project'] as ProjectSnapshot).id);
    } else if (r['type'] == 'open-folder') {
      _closeHistory();
      _triggerFolderOpen();
    } else if (r['type'] == 'clear-history') {
      setState(() {
        projectHistory = [];
        _saveHistory();
        historySelected = 0;
        _buildHistoryRows();
      });
    }
  }

  String _timeAgo(int ts) {
    final diff = DateTime.now().millisecondsSinceEpoch - ts;
    final mins = diff ~/ 60000;
    if (mins < 1) return 'just now';
    if (mins < 60) return '${mins}m ago';
    final hrs = mins ~/ 60;
    if (hrs < 24) return '${hrs}h ago';
    return '${hrs ~/ 24}d ago';
  }

  // ============================================================
  // KEYBOARD ACCESSORIES
  // ============================================================
  void _insertAtCaret(String str) {
    final sel = _codeController.selection;
    final start = sel.start;
    final end = sel.end;
    final val = _codeController.text;
    final newVal = val.substring(0, start) + str + val.substring(end);
    _codeController.text = newVal;
    _codeController.selection =
        TextSelection.collapsed(offset: start + str.length);
    _handleEditorInput();
  }

  void _wrapCaret(String left, String right) {
    final sel = _codeController.selection;
    final start = sel.start;
    final end = sel.end;
    final val = _codeController.text;
    final selected = val.substring(start, end);
    final newVal =
        val.substring(0, start) + left + selected + right + val.substring(end);
    _codeController.text = newVal;
    _codeController.selection = TextSelection(
      baseOffset: start + left.length,
      extentOffset: end + left.length,
    );
    _handleEditorInput();
  }

  void _toggleLineComment() {
    final sel = _codeController.selection;
    final val = _codeController.text;
    final lineStart = val.lastIndexOf('\n', sel.start - 1) + 1;
    String newVal;
    if (val.substring(lineStart, (lineStart + 2).clamp(0, val.length)) ==
        '//') {
      newVal = val.substring(0, lineStart) + val.substring(lineStart + 2);
    } else {
      newVal = val.substring(0, lineStart) + '// ' + val.substring(lineStart);
    }
    _codeController.text = newVal;
    _handleEditorInput();
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VS.bg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                if (findBarVisible) _buildFindBar(),
                Expanded(
                  child: Column(
                    children: [
                      _buildTabsBar(),
                      Expanded(
                        child: welcomeVisible
                            ? _buildWelcome()
                            : _buildEditorArea(),
                      ),
                      if (!welcomeVisible) _buildAccessoryBar(),
                    ],
                  ),
                ),
                _buildStatusBar(),
              ],
            ),
          ),
          if (sidebarOpen) _buildSidebarBackdrop(),
          _buildSidebarDrawer(),
          _buildContextSheet(),
          _buildHistoryPopup(),
          _buildDialog(),
          _buildSettingsPage(),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader() {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: VS.sidebar,
        border: Border(bottom: BorderSide(color: VS.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          _iconBtn(
            icon: Icons.menu,
            onTap: () => sidebarOpen ? _closeDrawer() : _openDrawer(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                Text(
                  (projectName ?? 'TEAPP').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '/',
                    style: TextStyle(color: VS.border, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    _activeFileName(),
                    style: const TextStyle(
                      color: VS.text,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          _iconBtn(
            icon: Icons.search,
            onTap: () => setState(() => findBarVisible = !findBarVisible),
          ),
          _iconBtn(
            icon: Icons.check,
            color: VS.accent,
            onTap: () async {
              final ok = await _persistState();
              setState(() => saveStatus = ok ? 'Synced' : 'Save Failed');
            },
          ),
          _iconBtn(
            icon: Icons.tune,
            onTap: () => setState(() => settingsOpen = true),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  String _activeFileName() {
    final active = nodes.firstWhere(
      (n) => n.id == activeTabId,
      orElse: () => FileNode(id: '', name: 'None', isFolder: false),
    );
    return active.name;
  }

  Widget _iconBtn({
    required IconData icon,
    VoidCallback? onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18, color: color ?? VS.text),
      ),
    );
  }

  // ============================================================
  // FIND BAR
  // ============================================================
  Widget _buildFindBar() {
    return Container(
      decoration: const BoxDecoration(
        color: VS.sidebar,
        border: Border(bottom: BorderSide(color: VS.border)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color: VS.editor,
                    border: Border.all(color: VS.border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _findController,
                          onChanged: (_) => _runFindSearch(),
                          style: const TextStyle(
                            color: VS.text,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Find in file...',
                            hintStyle:
                                TextStyle(color: VS.muted, fontSize: 12),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          findMatches.isEmpty
                              ? '0/0'
                              : '${currentMatchIndex + 1}/${findMatches.length}',
                          style: const TextStyle(
                            color: VS.muted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _toggleBtn('Aa', findMatchCase, () {
                setState(() => findMatchCase = !findMatchCase);
                _runFindSearch();
              }),
              const SizedBox(width: 4),
              _toggleBtn(r'\b', findWholeWord, () {
                setState(() => findWholeWord = !findWholeWord);
                _runFindSearch();
              }),
              const SizedBox(width: 4),
              _smallBtn('↑', _findPrev),
              const SizedBox(width: 2),
              _smallBtn('↓', _findNext),
              const SizedBox(width: 4),
              _smallBtn('✕', () => setState(() => findBarVisible = false)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color: VS.editor,
                    border: Border.all(color: VS.border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TextField(
                    controller: _replaceController,
                    style: const TextStyle(
                      color: VS.text,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Replace with...',
                      hintStyle: TextStyle(color: VS.muted, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _accentBtn('Replace', _replaceCurrentMatch),
              const SizedBox(width: 4),
              _smallBtn('All', _replaceAllMatches),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? VS.accent : Colors.transparent,
          border: Border.all(color: VS.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : VS.muted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Widget _smallBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: VS.border,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: VS.text,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Widget _accentBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: VS.accent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TABS BAR
  // ============================================================
  Widget _buildTabsBar() {
    if (openTabs.isEmpty) {
      return Container(
        height: 36,
        decoration: const BoxDecoration(
          color: VS.tabInactive,
          border: Border(bottom: BorderSide(color: VS.border)),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: const Text(
          'No Open Buffer',
          style: TextStyle(
            color: VS.muted,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      );
    }
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: VS.tabInactive,
        border: Border(bottom: BorderSide(color: VS.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: openTabs.map((id) {
          final file = nodes.firstWhere(
            (n) => n.id == id,
            orElse: () => FileNode(id: '', name: '', isFolder: false),
          );
          if (file.id.isEmpty) return const SizedBox.shrink();
          final isCurrent = activeTabId == id;
          return InkWell(
            onTap: () {
              setState(() => activeTabId = id);
              _mountEditor();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isCurrent ? VS.tabActive : VS.tabInactive,
                border: Border(
                  right: const BorderSide(color: VS.border),
                  top: BorderSide(
                    color: isCurrent ? VS.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 14,
                    color: isCurrent ? VS.accent : VS.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    file.name,
                    style: TextStyle(
                      color: isCurrent ? Colors.white : VS.muted,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _closeTab(id),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.close, size: 12, color: VS.muted),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // WELCOME SCREEN
  // ============================================================
  Widget _buildWelcome() {
    return Container(
      color: VS.editor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, size: 56, color: VS.muted),
            const SizedBox(height: 16),
            const Text(
              'No folder opened',
              style: TextStyle(
                color: VS.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Open a local project folder — just like VS Code — to start editing its files here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: VS.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: _triggerFolderOpen,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: VS.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Open Folder',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EDITOR AREA
  // ============================================================
  Widget _buildEditorArea() {
    final active = nodes.firstWhere(
      (n) => n.id == activeTabId,
      orElse: () => FileNode(id: '', name: '', isFolder: false),
    );
    final lang = _getLanguage(active.name);
    final code = _codeController.text;
    final fontSize = settings.fontSize.toDouble();
    final lineHeight = (fontSize + 7);

    final totalLines = code.split('\n').length;

    return Container(
      color: VS.editor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (settings.lineNumbers)
            Container(
              width: 44,
              padding: const EdgeInsets.only(top: 12, right: 8),
              decoration: const BoxDecoration(
                color: VS.editor,
                border: Border(right: BorderSide(color: Color(0x55282828))),
              ),
              child: SingleChildScrollView(
                controller: _gutterScroll,
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(
                    totalLines,
                    (i) => SizedBox(
                      height: lineHeight,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: const Color(0xFF606060),
                          fontSize: fontSize,
                          height: 1,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    controller: _verticalScroll,
                    physics: const ClampingScrollPhysics(),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _horizontalScroll,
                      physics: const ClampingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: RichText(
                          text: TextSpan(
                            children: _highlightCode(
                                code, lang, fontSize, lineHeight),
                          ),
                          softWrap: settings.wordWrap,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: SingleChildScrollView(
                    controller: _verticalScroll,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _horizontalScroll,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width,
                            minHeight: MediaQuery.of(context).size.height,
                          ),
                          child: TextField(
                            controller: _codeController,
                            focusNode: _codeFocus,
                            maxLines: null,
                            expands: false,
                            style: TextStyle(
                              color: Colors.transparent,
                              fontFamily: 'monospace',
                              fontSize: fontSize,
                              height: lineHeight / fontSize,
                              letterSpacing: 0,
                            ),
                            cursorColor: Colors.white,
                            cursorWidth: 2,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (_) => _handleEditorInput(),
                            onTap: _updateCaretStatus,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            scrollPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACCESSORY BAR
  // ============================================================
  Widget _buildAccessoryBar() {
    final buttons = [
      {'label': 'TAB', 'onTap': () => _insertAtCaret('  ')},
      {'label': '{ }', 'onTap': () => _wrapCaret('{', '}')},
      {'label': '( )', 'onTap': () => _wrapCaret('(', ')')},
      {'label': '[ ]', 'onTap': () => _wrapCaret('[', ']')},
      {'label': ';', 'onTap': () => _insertAtCaret(';')},
      {'label': ':', 'onTap': () => _insertAtCaret(':')},
      {'label': "' '", 'onTap': () => _wrapCaret("'", "'")},
      {'label': '" "', 'onTap': () => _wrapCaret('"', '"')},
      {'label': '=>', 'onTap': () => _insertAtCaret('=>')},
      {'label': '=', 'onTap': () => _insertAtCaret(' = ')},
      {'label': '//', 'onTap': _toggleLineComment},
    ];
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: VS.sidebar,
        border: Border(top: BorderSide(color: VS.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        children: buttons
            .map((b) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
                  child: InkWell(
                    onTap: b['onTap'] as VoidCallback,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xCC282828),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        b['label'] as String,
                        style: const TextStyle(
                          color: VS.text,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ============================================================
  // STATUS BAR
  // ============================================================
  Widget _buildStatusBar() {
    final active = nodes.firstWhere(
      (n) => n.id == activeTabId,
      orElse: () => FileNode(id: '', name: '', isFolder: false),
    );
    final lang = active.id.isEmpty ? 'Plain' : _getLanguage(active.name);
    return Container(
      height: 20,
      color: VS.accent,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Text('→', style: TextStyle(color: Colors.white, fontSize: 10)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              projectName ?? 'TEAPP',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            saveStatus,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 12),
          Text(
            caretPos,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 12),
          Text(
            lang,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Spaces: ${settings.tabSize}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'UTF-8',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SIDEBAR BACKDROP
  // ============================================================
  Widget _buildSidebarBackdrop() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _closeDrawer,
        child: Container(color: Colors.black54),
      ),
    );
  }

  // ============================================================
  // SIDEBAR DRAWER
  // ============================================================
  Widget _buildSidebarDrawer() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      left: sidebarOpen ? 0 : -320,
      top: 0,
      bottom: 0,
      width: 320,
      child: Container(
        decoration: const BoxDecoration(
          color: VS.sidebar,
          border: Border(right: BorderSide(color: VS.border)),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
        ),
        child: Row(
          children: [
            _buildActivityRail(),
            Expanded(child: _buildSidebarBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRail() {
    if (railCollapsed) {
      return GestureDetector(
        onDoubleTap: () => setState(() => railCollapsed = false),
        child: Container(
          width: 8,
          color: VS.accent.withOpacity(0.4),
        ),
      );
    }
    return GestureDetector(
      onDoubleTap: () => setState(() => railCollapsed = true),
      child: Container(
        width: 48,
        decoration: const BoxDecoration(
          color: VS.activityBar,
          border: Border(right: BorderSide(color: Color(0x99282828))),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _railBtn(Icons.folder_outlined, 'explorer'),
            _railBtn(Icons.code, 'github'),
            _railBtn(Icons.smart_toy_outlined, 'ai'),
            _railBtn(Icons.history, 'project'),
          ],
        ),
      ),
    );
  }

  Widget _railBtn(IconData icon, String tab) {
    final active = activeSideTab == tab && tab != 'project';
    return InkWell(
      onTap: () {
        if (tab == 'project') {
          _openHistory();
        } else {
          _switchActivityTab(tab);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: active ? VS.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Icon(icon, size: 20, color: active ? Colors.white : VS.muted),
      ),
    );
  }

  Widget _buildSidebarBody() {
    if (activeSideTab == 'explorer') return _buildExplorerPane();
    if (activeSideTab == 'github') return _buildGithubPane();
    if (activeSideTab == 'ai') return _buildAIPane();
    return const SizedBox.shrink();
  }

  // ============================================================
  // EXPLORER PANE
  // ============================================================
  Widget _buildExplorerPane() {
    return Column(
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: VS.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _triggerFolderOpen,
                  child: Text(
                    (projectName ?? 'TEAPP').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              _iconBtn(
                icon: Icons.add,
                onTap: () =>
                    _openDialog('Create Root File', 'Location: /', '', (name) {
                  final file = FileNode(
                    id: 'f_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    isFolder: false,
                    parentId: null,
                    content: '',
                  );
                  setState(() => nodes.add(file));
                  _openFile(file.id);
                }),
              ),
              _iconBtn(
                icon: Icons.create_new_folder_outlined,
                onTap: () => _openDialog(
                    'Create Root Folder', 'Location: /', '', (name) {
                  setState(() => nodes.add(FileNode(
                        id: 'd_${DateTime.now().millisecondsSinceEpoch}',
                        name: name,
                        isFolder: true,
                        parentId: null,
                        isOpen: true,
                      )));
                  _persistState();
                }),
              ),
              _iconBtn(icon: Icons.close, onTap: _closeDrawer),
            ],
          ),
        ),
        Expanded(
          child: nodes.isEmpty ? _emptyExplorer() : _buildTree(null, 0),
        ),
      ],
    );
  }

  Widget _emptyExplorer() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No folder opened yet.',
              style: TextStyle(color: VS.muted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _triggerFolderOpen,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: VS.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Open Folder',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTree(String? parentId, int depth) {
    final items = nodes.where((n) => n.parentId == parentId).toList();
    items.sort((a, b) {
      if (a.isFolder == b.isFolder) return a.name.compareTo(b.name);
      return a.isFolder ? -1 : 1;
    });

    final rows = <Widget>[];
    for (final node in items) {
      final isActive = activeTabId == node.id;
      rows.add(InkWell(
        onTap: () {
          if (node.isFolder) {
            setState(() => node.isOpen = !node.isOpen);
          } else {
            _openFile(node.id);
            _closeDrawer();
          }
        },
        child: Container(
          padding: EdgeInsets.only(
            left: depth * 14 + 10,
            right: 6,
            top: 4,
            bottom: 4,
          ),
          color: isActive ? VS.selected : Colors.transparent,
          child: Row(
            children: [
              if (node.isFolder)
                AnimatedRotation(
                  turns: node.isOpen ? 0.25 : 0,
                  duration: const Duration(milliseconds: 100),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: VS.muted,
                  ),
                )
              else
                const SizedBox(width: 14),
              const SizedBox(width: 4),
              Icon(
                node.isFolder ? Icons.folder : Icons.description_outlined,
                size: 16,
                color: node.isFolder ? VS.blueFolder : VS.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.name,
                  style: TextStyle(
                    color: isActive ? Colors.white : VS.text,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight:
                        isActive ? FontWeight.w500 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => _openActionSheet(node.id),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.more_vert, size: 14, color: VS.muted),
                ),
              ),
            ],
          ),
        ),
      ));
      if (node.isFolder && node.isOpen) {
        rows.addAll(_treeChildren(node.id, depth + 1));
      }
    }
    return ListView(padding: EdgeInsets.zero, children: rows);
  }

  List<Widget> _treeChildren(String parentId, int depth) {
    final items = nodes.where((n) => n.parentId == parentId).toList();
    items.sort((a, b) {
      if (a.isFolder == b.isFolder) return a.name.compareTo(b.name);
      return a.isFolder ? -1 : 1;
    });
    final rows = <Widget>[];
    for (final node in items) {
      final isActive = activeTabId == node.id;
      rows.add(InkWell(
        onTap: () {
          if (node.isFolder) {
            setState(() => node.isOpen = !node.isOpen);
          } else {
            _openFile(node.id);
            _closeDrawer();
          }
        },
        child: Container(
          padding: EdgeInsets.only(
            left: depth * 14 + 10,
            right: 6,
            top: 4,
            bottom: 4,
          ),
          color: isActive ? VS.selected : Colors.transparent,
          child: Row(
            children: [
              if (node.isFolder)
                AnimatedRotation(
                  turns: node.isOpen ? 0.25 : 0,
                  duration: const Duration(milliseconds: 100),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: VS.muted,
                  ),
                )
              else
                const SizedBox(width: 14),
              const SizedBox(width: 4),
              Icon(
                node.isFolder ? Icons.folder : Icons.description_outlined,
                size: 16,
                color: node.isFolder ? VS.blueFolder : VS.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.name,
                  style: TextStyle(
                    color: isActive ? Colors.white : VS.text,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => _openActionSheet(node.id),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.more_vert, size: 14, color: VS.muted),
                ),
              ),
            ],
          ),
        ),
      ));
      if (node.isFolder && node.isOpen) {
        rows.addAll(_treeChildren(node.id, depth + 1));
      }
    }
    return rows;
  }

  // ============================================================
  // GITHUB PANE
  // ============================================================
  Widget _buildGithubPane() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'SOURCE CONTROL: GIT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              _iconBtn(icon: Icons.close, onTap: _closeDrawer),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VS.bg,
              border: Border.all(color: VS.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              children: [
                Text(
                  'Branch: ',
                  style: TextStyle(
                    color: VS.muted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'main',
                  style: TextStyle(
                    color: VS.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 80,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VS.bg,
              border: Border.all(color: VS.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const TextField(
              maxLines: null,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: 'Commit message...',
                hintStyle: TextStyle(color: VS.muted, fontSize: 12),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: InkWell(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: VS.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Commit Changes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AI PANE
  // ============================================================
  Widget _buildAIPane() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'AGENTIC AI ASSISTANT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              _iconBtn(icon: Icons.close, onTap: _closeDrawer),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VS.bg,
                border: Border.all(color: VS.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: VS.card,
                      border: Border.all(color: VS.border),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Autonomous Agent: ',
                            style: TextStyle(
                              color: VS.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                          TextSpan(
                            text:
                                'Ready to inspect code, generate files, and debug workspace.',
                            style: TextStyle(
                              color: VS.text,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: VS.bg,
                    border: Border.all(color: VS.border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const TextField(
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: 'Prompt Agent...',
                      hintStyle: TextStyle(color: VS.muted, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _accentBtn('Run', () {}),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTEXT SHEET
  // ============================================================
  Widget _buildContextSheet() {
    if (!contextSheetVisible) return const SizedBox.shrink();
    final node = nodes.firstWhere(
      (n) => n.id == contextNodeId,
      orElse: () => FileNode(id: '', name: '', isFolder: false),
    );
    if (node.id.isEmpty) return const SizedBox.shrink();
    final isFolder = node.isFolder;

    return Positioned.fill(
      child: GestureDetector(
        onTap: _closeActionSheet,
        child: Container(
          color: Colors.black54,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: const BoxDecoration(
                color: VS.sidebar,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                border: Border(top: BorderSide(color: VS.border)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: VS.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getFullPath(node.id),
                    style: const TextStyle(
                      color: VS.muted,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (isFolder) ...[
                    _sheetBtn(Icons.add, 'New File Here', () {
                      _openDialog('New Nested File',
                          'Inside: ${_getFullPath(node.id)}', '', (name) {
                        final file = FileNode(
                          id: 'f_${DateTime.now().millisecondsSinceEpoch}',
                          name: name,
                          isFolder: false,
                          parentId: node.id,
                          content: '',
                        );
                        setState(() {
                          nodes.add(file);
                          node.isOpen = true;
                        });
                        _openFile(file.id);
                      });
                    }),
                    _sheetBtn(
                      Icons.create_new_folder_outlined,
                      'New Folder Here',
                      () {
                        _openDialog('New Nested Folder',
                            'Inside: ${_getFullPath(node.id)}', '', (name) {
                          setState(() {
                            nodes.add(FileNode(
                              id:
                                  'd_${DateTime.now().millisecondsSinceEpoch}',
                              name: name,
                              isFolder: true,
                              parentId: node.id,
                              isOpen: true,
                            ));
                            node.isOpen = true;
                          });
                          _persistState();
                        });
                      },
                    ),
                    const Divider(color: VS.border, height: 1),
                  ],
                  _sheetBtn(Icons.edit_outlined, 'Rename', () {
                    _openDialog('Rename Item', 'Current: ${node.name}',
                        node.name, (newName) {
                      setState(() => node.name = newName);
                      _persistState();
                      _mountEditor();
                    });
                  }),
                  _sheetBtn(
                    Icons.delete_outline,
                    'Delete Permanent',
                    isDanger: true,
                    () {
                      _closeActionSheet();
                      _cascadeDelete(node.id);
                      _persistState();
                      _mountEditor();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _cascadeDelete(String id) {
    final kids = nodes.where((n) => n.parentId == id).toList();
    for (final k in kids) {
      _cascadeDelete(k.id);
    }
    nodes.removeWhere((n) => n.id == id);
    _closeTab(id);
  }

  Widget _sheetBtn(IconData icon, String label, VoidCallback onTap,
      {bool isDanger = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isDanger ? VS.danger : VS.muted),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isDanger ? VS.danger : VS.text,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MODAL DIALOG
  // ============================================================
  Widget _buildDialog() {
    if (!dialogVisible) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: VS.sidebar,
            border: Border.all(color: VS.border),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dialogTitle.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                dialogSubtitle,
                style: const TextStyle(
                  color: VS.muted,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Container(
                height: 34,
                decoration: BoxDecoration(
                  color: VS.editor,
                  border: Border.all(color: VS.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TextField(
                  controller: _dialogController,
                  autofocus: true,
                  style: const TextStyle(
                    color: VS.text,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _closeDialog,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: VS.muted, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _confirmDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: VS.accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PROJECT HISTORY POPUP
  // ============================================================
  Widget _buildHistoryPopup() {
    if (!historyVisible) return const SizedBox.shrink();
    return Positioned.fill(
      child: GestureDetector(
        onTap: _closeHistory,
        child: Container(
          color: Colors.black54,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 60, left: 16, right: 16),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              decoration: BoxDecoration(
                color: VS.sidebar,
                border: Border.all(color: VS.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: VS.border)),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '>',
                          style: TextStyle(
                            color: VS.muted,
                            fontSize: 14,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _historySearchController,
                            onChanged: (v) => setState(() {
                              historyQuery = v;
                              historySelected = 0;
                              _buildHistoryRows();
                            }),
                            autofocus: true,
                            style: const TextStyle(
                              color: VS.text,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Search recent projects...',
                              hintStyle: TextStyle(
                                color: VS.muted,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _closeHistory,
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                            color: VS.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: SingleChildScrollView(
                      child: Column(
                        children:
                            historyRows.asMap().entries.map((e) {
                          final idx = e.key;
                          final row = e.value;
                          final isSelected = idx == historySelected;
                          if (row['type'] == 'project') {
                            final p = row['project'] as ProjectSnapshot;
                            return InkWell(
                              onTap: () => _openProjectFromHistory(p.id),
                              child: Container(
                                color: isSelected
                                    ? VS.accent
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.folder_outlined,
                                      size: 16,
                                      color: isSelected
                                          ? Colors.white
                                          : VS.accent,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        p.name,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : VS.text,
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${p.fileCount} files • ${_timeAgo(p.savedAt)}',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white70
                                            : VS.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          projectHistory.removeWhere(
                                              (x) => x.id == p.id);
                                          _saveHistory();
                                          _buildHistoryRows();
                                        });
                                      },
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: isSelected
                                            ? Colors.white70
                                            : VS.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else if (row['type'] == 'open-folder') {
                            return InkWell(
                              onTap: () {
                                _closeHistory();
                                _triggerFolderOpen();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                color: isSelected
                                    ? VS.accent
                                    : Colors.transparent,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.add,
                                      size: 16,
                                      color: isSelected
                                          ? Colors.white
                                          : VS.accent,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Open Folder...',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : VS.accent,
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else {
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  projectHistory = [];
                                  _saveHistory();
                                  historySelected = 0;
                                  _buildHistoryRows();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                color: isSelected
                                    ? VS.accent
                                    : Colors.transparent,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                      color: isSelected
                                          ? Colors.white
                                          : VS.danger,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Clear History',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : VS.danger,
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SETTINGS PAGE
  // ============================================================
  Widget _buildSettingsPage() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      left: settingsOpen ? 0 : MediaQuery.of(context).size.width,
      top: 0,
      bottom: 0,
      right: 0,
      child: Container(
        color: const Color(0xFF161616),
        child: Column(
          children: [
            Container(
              height: 48,
              decoration: const BoxDecoration(
                color: VS.sidebar,
                border: Border(bottom: BorderSide(color: VS.border)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: VS.text,
                    ),
                    onPressed: () => setState(() => settingsOpen = false),
                  ),
                  const Text(
                    'Preferences',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove(_storageKey);
                      setState(() {
                        projectName = null;
                        settings = EditorSettings();
                        nodes = [];
                        openTabs = [];
                        activeTabId = null;
                      });
                      _persistState();
                    },
                    child: const Text(
                      'Reset Defaults',
                      style: TextStyle(
                        color: VS.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPreviewCard(),
                    const SizedBox(height: 20),
                    const Text(
                      'EDITOR TYPOGRAPHY',
                      style: TextStyle(
                        color: VS.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: VS.card,
                        border: Border.all(color: VS.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          _settingsRow(
                            'Font Size',
                            'Code canvas text scaling',
                            Row(
                              children: [
                                _stepBtn('-', () {
                                  if (settings.fontSize > 10) {
                                    setState(() => settings.fontSize--);
                                    _persistState();
                                  }
                                }),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '${settings.fontSize}px',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _stepBtn('+', () {
                                  if (settings.fontSize < 22) {
                                    setState(() => settings.fontSize++);
                                    _persistState();
                                  }
                                }),
                              ],
                            ),
                          ),
                          const Divider(color: Color(0x44282828), height: 1),
                          _settingsRow(
                            'Tab Spacing',
                            'Indentation column width',
                            Row(
                              children: [
                                _pillBtn('2 Sp', settings.tabSize == 2, () {
                                  setState(() => settings.tabSize = 2);
                                  _persistState();
                                }),
                                const SizedBox(width: 4),
                                _pillBtn('4 Sp', settings.tabSize == 4, () {
                                  setState(() => settings.tabSize = 4);
                                  _persistState();
                                }),
                              ],
                            ),
                          ),
                          const Divider(color: Color(0x44282828), height: 1),
                          _settingsRow(
                            'Line Numbers',
                            'Show left gutter count',
                            _switch(settings.lineNumbers, (v) {
                              setState(() => settings.lineNumbers = v);
                              _persistState();
                            }),
                          ),
                          const Divider(color: Color(0x44282828), height: 1),
                          _settingsRow(
                            'Word Wrap',
                            'Wrap lines to viewport',
                            _switch(settings.wordWrap, (v) {
                              setState(() => settings.wordWrap = v);
                              _persistState();
                            }),
                          ),
                        ],
                      ),
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

  Widget _buildPreviewCard() {
    final fontSize = settings.fontSize.toDouble();
    final lineHeight = fontSize + 7;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VS.card,
        border: Border.all(color: VS.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'LIVE PREVIEW',
                style: TextStyle(
                  color: VS.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                '${settings.fontSize}px • ${settings.tabSize} Spaces',
                style: const TextStyle(
                  color: VS.accent,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: VS.bg,
              border: Border.all(color: const Color(0x99282828)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (settings.lineNumbers)
                  Container(
                    width: 32,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 6,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Color(0x88282828)),
                      ),
                    ),
                    child: Column(
                      children: List.generate(
                        4,
                        (i) => SizedBox(
                          height: lineHeight,
                          child: Text(
                            '${i + 1}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: const Color(0xFF606060),
                              fontSize: fontSize,
                              height: 1,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: fontSize,
                          height: lineHeight / fontSize,
                        ),
                        children: [
                          const TextSpan(
                            text: 'void ',
                            style: TextStyle(
                              color: Tok.keyword,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const TextSpan(
                            text: 'main',
                            style: TextStyle(color: Tok.func),
                          ),
                          const TextSpan(
                            text: '() {\n',
                            style: TextStyle(color: VS.text),
                          ),
                          TextSpan(
                            text: ' ' * settings.tabSize,
                            style: const TextStyle(color: VS.text),
                          ),
                          const TextSpan(
                            text: 'runApp',
                            style: TextStyle(color: Tok.type),
                          ),
                          const TextSpan(
                            text: '(',
                            style: TextStyle(color: VS.text),
                          ),
                          const TextSpan(
                            text:
                                "'Live Mobile Preview Code With Long Word-Wrapping Line'",
                            style: TextStyle(color: Tok.string),
                          ),
                          const TextSpan(
                            text: ');\n',
                            style: TextStyle(color: VS.text),
                          ),
                          TextSpan(
                            text: ' ' * settings.tabSize,
                            style: const TextStyle(color: VS.text),
                          ),
                          const TextSpan(
                            text: 'return',
                            style: TextStyle(
                              color: Tok.keyword,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const TextSpan(
                            text: ';\n',
                            style: TextStyle(color: VS.text),
                          ),
                          const TextSpan(
                            text: '}',
                            style: TextStyle(color: VS.text),
                          ),
                        ],
                      ),
                      softWrap: settings.wordWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsRow(String title, String subtitle, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: VS.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _stepBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: VS.bg,
          border: Border.all(color: VS.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _pillBtn(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? VS.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : VS.muted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Widget _switch(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42,
        height: 24,
        decoration: BoxDecoration(
          color: value ? VS.accent : const Color(0xFF333333),
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HELPER CLASSES FOR SYNTAX HIGHLIGHTING
// ============================================================
class _Pattern {
  final RegExp regex;
  final Color color;
  _Pattern(this.regex, this.color);
}

class _Token {
  final int start, end;
  final Color color;
  _Token(this.start, this.end, this.color);
}
