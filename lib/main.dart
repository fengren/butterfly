import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'record_page.dart';
import 'audio_player_page.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'theme_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return MaterialApp(
      title: '录音播放器',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeNotifier.themeMode,
      home: const FileListPage(),
    );
  }
}

class FileListPage extends StatefulWidget {
  const FileListPage({super.key});

  @override
  State<FileListPage> createState() => _FileListPageState();
}

// 空白功能页面
class ProPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('升级到专业版')),
    body: const Center(child: Text('Pro 空页面')),
  );
}

class ThemePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('主题')),
    body: const Center(child: Text('主题 空页面')),
  );
}

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设置')),
    body: const Center(child: Text('设置 空页面')),
  );
}

class FAQPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('常见问题')),
    body: const Center(child: Text('常见问题 空页面')),
  );
}

class MoreAppsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('更多应用')),
    body: const Center(child: Text('更多应用 空页面')),
  );
}

class FeedbackPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('反馈')),
    body: const Center(child: Text('反馈 空页面')),
  );
}

class AppFilesPage extends StatefulWidget {
  @override
  State<AppFilesPage> createState() => _AppFilesPageState();
}

class _AppFilesPageState extends State<AppFilesPage> {
  String? currentPath;
  String? rootPath;

  @override
  void initState() {
    super.initState();
    _initRoot();
  }

  Future<void> _initRoot() async {
    final dir = await getApplicationDocumentsDirectory();
    setState(() {
      currentPath = dir.path;
      rootPath = dir.path;
    });
  }

  Future<List<FileSystemEntity>> _loadFiles(String path) async {
    final dir = Directory(path);
    return dir.listSync();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _iconForFile(FileSystemEntity entity) {
    if (entity is Directory) return Icons.folder;
    final name = entity.path.toLowerCase();
    if (name.endsWith('.aac') ||
        name.endsWith('.m4a') ||
        name.endsWith('.wav') ||
        name.endsWith('.mp3')) {
      return Icons.audiotrack;
    }
    if (name.endsWith('.json')) return Icons.description;
    return Icons.insert_drive_file;
  }

  @override
  Widget build(BuildContext context) {
    if (currentPath == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('应用内文件')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('应用内文件'),
        leading: _showBack()
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () async {
                  final parent = Directory(currentPath!).parent;
                  if (rootPath != null &&
                      parent.path.length >= rootPath!.length) {
                    setState(() {
                      currentPath = parent.path;
                    });
                  }
                },
              )
            : null,
      ),
      body: FutureBuilder<List<FileSystemEntity>>(
        future: _loadFiles(currentPath!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('暂无文件'));
          }
          final files = snapshot.data!;
          files.sort((a, b) {
            if (a is Directory && b is! Directory) return -1;
            if (a is! Directory && b is Directory) return 1;
            return a.path.compareTo(b.path);
          });
          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final stat = file.statSync();
              final fileName = file.path.split(Platform.pathSeparator).last;
              final icon = _iconForFile(file);
              return ListTile(
                leading: Icon(
                  icon,
                  color: icon == Icons.folder ? Colors.amber : null,
                ),
                title: Text(fileName),
                subtitle: file is Directory
                    ? Text('文件夹')
                    : Text(
                        '${_formatFileSize(stat.size)}  |  ${stat.modified.year}/${stat.modified.month.toString().padLeft(2, '0')}/${stat.modified.day.toString().padLeft(2, '0')}  ${stat.modified.hour.toString().padLeft(2, '0')}:${stat.modified.minute.toString().padLeft(2, '0')}',
                      ),
                onTap: file is Directory
                    ? () {
                        setState(() {
                          currentPath = file.path;
                        });
                      }
                    : file.path.toLowerCase().endsWith('.json')
                    ? () async {
                        String content = '';
                        try {
                          content = await File(file.path).readAsString();
                        } catch (e) {
                          content = '读取失败: $e';
                        }
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              file.path.split(Platform.pathSeparator).last,
                            ),
                            content: SingleChildScrollView(
                              child: SelectableText(
                                content.length > 5000
                                    ? content.substring(0, 5000) +
                                          '\n...内容过长已截断'
                                    : content,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('关闭'),
                              ),
                            ],
                          ),
                        );
                      }
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  bool _showBack() {
    if (currentPath == null || rootPath == null) return false;
    return currentPath != rootPath;
  }
}

class _FileListPageState extends State<FileListPage> {
  List<Map<String, dynamic>> _metaDataList = [];
  List<FileSystemEntity> files = [];
  bool loading = true;
  final Map<String, String> _durationCache = {};
  Map<FileSystemEntity, String> _fileTags = {};

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadMetaData() async {
    final metaFile = await _getMetaFile();
    if (await metaFile.exists()) {
      final content = await metaFile.readAsString();
      final List<dynamic> list = jsonDecode(content);
      _metaDataList = List<Map<String, dynamic>>.from(
        list.map((e) => Map<String, dynamic>.from(e)),
      );
      // 自动修正所有displayName为纯文件名
      bool needFix = false;
      for (final meta in _metaDataList) {
        if (meta['displayName'] != null) {
          final dn = meta['displayName'] as String;
          final dotIdx = dn.lastIndexOf('.');
          final fixed = dotIdx > 0 ? dn.substring(0, dotIdx) : dn;
          if (fixed != dn) {
            meta['displayName'] = fixed;
            needFix = true;
          }
        }
      }
      if (needFix) {
        await metaFile.writeAsString(jsonEncode(_metaDataList));
      }
    } else {
      // 自动生成meta.json
      final dir = await getApplicationDocumentsDirectory();
      List<Map<String, dynamic>> autoList = [];
      final allFiles = Directory(dir.path).listSync(recursive: true);
      for (final f in allFiles) {
        if (f is File) {
          final path = f.path;
          final lower = path.toLowerCase();
          if (lower.endsWith('.aac') ||
              lower.endsWith('.m4a') ||
              lower.endsWith('.wav') ||
              lower.endsWith('.mp3')) {
            // 取文件夹名为id
            final parts = path.replaceFirst(dir.path + '/', '').split('/');
            if (parts.length < 2) continue;
            final folder = parts[0];
            final audioFileName = parts.last;
            final audioRelPath = '$folder/$audioFileName';
            final waveRelPath = '$audioRelPath.wave.json';
            final marksRelPath = '$audioRelPath.marks.json';
            autoList.add({
              'id': folder,
              'audioPath': audioRelPath,
              'wavePath': waveRelPath,
              'marksPath': marksRelPath,
              'displayName': audioFileName,
              'tag': '--',
              'created': File(path).statSync().modified.toIso8601String(),
              'played': false,
            });
          }
        }
      }
      _metaDataList = autoList;
      await metaFile.writeAsString(jsonEncode(_metaDataList));
    }
  }

  Future<void> _loadFiles() async {
    await _loadMetaData();
    setState(() {
      loading = true;
    });
    try {
      List<FileSystemEntity> audioFiles = [];
      Directory dir = await getApplicationDocumentsDirectory();
      for (final item in _metaDataList) {
        final file = File('${dir.path}/${item['audioPath']}');
        if (await file.exists()) {
          audioFiles.add(file);
        }
      }
      audioFiles.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
      _durationCache.clear();
      setState(() {
        files = audioFiles;
        loading = false;
      });
    } catch (e) {
      setState(() {
        files = [];
        loading = false;
      });
    }
  }

  Future<void> _renameFile(Map<String, dynamic> meta) async {
    final audioPath = meta['audioPath'] as String;
    final extension = '.aac'; // 始终为 audio.aac
    final nameWithoutExt = meta['displayName'] ?? audioPath.split('/').first;
    final textController = TextEditingController(text: nameWithoutExt);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(
          '重命名文件',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '文件名',
            hintText: '请输入新的文件名',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, textController.text);
            },
            child: Text(
              '确定',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != nameWithoutExt) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final folder = audioPath.split('/').first;
        final oldAudioPath = '${dir.path}/$audioPath';
        final newAudioPath = '$folder/$newName$extension';
        final newFile = File('${dir.path}/$newAudioPath');
        await File(oldAudioPath).rename(newFile.path);
        // wave/marks文件
        final oldWaveFile = File('${dir.path}/${meta['wavePath']}');
        final newWaveFile = File('${dir.path}/$folder/wave.json');
        if (await oldWaveFile.exists()) {
          await oldWaveFile.rename(newWaveFile.path);
        }
        final oldMarksFile = File('${dir.path}/${meta['marksPath']}');
        final newMarksFile = File('${dir.path}/$folder/marks.json');
        if (await oldMarksFile.exists()) {
          await oldMarksFile.rename(newMarksFile.path);
        }
        // 更新meta
        meta['audioPath'] = newAudioPath;
        meta['wavePath'] = '$folder/wave.json';
        meta['marksPath'] = '$folder/marks.json';
        meta['displayName'] = newName;
        await _saveMetaData();
        _loadFiles();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '文件重命名成功',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '重命名失败: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteFile(Map<String, dynamic> meta) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(
          '删除文件',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '确定要删除文件 "${meta['displayName'] ?? meta['audioPath']}" 吗？',
          style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('删除', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final audioPath = meta['audioPath'] as String;
        final folderName = audioPath.split('/').first;
        final folder = Directory('${dir.path}/$folderName');
        if (await folder.exists()) {
          await folder.delete(recursive: true);
        }
        // 从metaList移除
        _metaDataList.remove(meta);
        await _saveMetaData();
        _loadFiles();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '文件删除成功',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '删除失败: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<String> _getAudioDuration(String filePath) async {
    // 检查缓存
    if (_durationCache.containsKey(filePath)) {
      return _durationCache[filePath]!;
    }
    try {
      // 兼容相对路径，拼接绝对路径
      String absPath = filePath;
      if (!File(filePath).isAbsolute) {
        final dir = await getApplicationDocumentsDirectory();
        absPath = '${dir.path}/$filePath';
      }
      // 尝试从波形文件获取时长信息
      final waveFile = File('$absPath.wave.json');
      if (await waveFile.exists()) {
        final content = await waveFile.readAsString();
        final data = jsonDecode(content);
        final waveform = List<double>.from(
          data.map((e) => (e as num).toDouble()),
        );
        final estimatedSeconds = (waveform.length / 16).round();
        final duration = _formatDuration(estimatedSeconds);
        _durationCache[filePath] = duration;
        return duration;
      }
      // 如果没有波形文件，尝试读取音频真实时长
      final audioPlayer = AudioPlayer();
      await audioPlayer.setSource(DeviceFileSource(absPath));
      final durationObj = await audioPlayer.getDuration();
      if (durationObj != null) {
        final seconds = durationObj.inSeconds;
        final duration = _formatDuration(seconds);
        _durationCache[filePath] = duration;
        return duration;
      }
    } catch (e) {
      // ignore
    }
    const duration = '未知时长';
    _durationCache[filePath] = duration;
    return duration;
  }

  void _showThemeDialog(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            '主题',
            style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<AppThemeMode>(
                title: Text(
                  '亮色模式',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                value: AppThemeMode.light,
                groupValue: themeNotifier.appThemeMode,
                onChanged: (value) {
                  themeNotifier.setTheme(value!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<AppThemeMode>(
                title: Text(
                  '暗色模式',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                value: AppThemeMode.dark,
                groupValue: themeNotifier.appThemeMode,
                onChanged: (value) {
                  themeNotifier.setTheme(value!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<AppThemeMode>(
                title: Text(
                  '追踪系统',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                value: AppThemeMode.system,
                groupValue: themeNotifier.appThemeMode,
                onChanged: (value) {
                  themeNotifier.setTheme(value!);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '选择',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFileMoreMenu(BuildContext context, Map<String, dynamic> meta) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuItem(context, Icons.text_snippet, 'AI转文字', pro: true),
              _buildMenuItem(
                context,
                Icons.edit,
                '重命名',
                onTap: () {
                  Navigator.pop(context);
                  _renameFile(meta);
                },
              ),
              _buildMenuItem(
                context,
                Icons.bookmark,
                '编辑标签',
                onTap: () {
                  Navigator.pop(context);
                  _editTagDialog(context, meta);
                },
              ),
              _buildMenuItem(
                context,
                Icons.delete,
                '删除',
                onTap: () {
                  Navigator.pop(context);
                  _deleteFile(meta);
                },
              ),
              Divider(height: 1),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  alignment: Alignment.center,
                  height: 48,
                  child: Text(
                    '取消',
                    style: TextStyle(
                      fontSize: 17,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String text, {
    bool pro = false,
    bool ad = false,
    bool showDot = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Stack(
                children: [
                  Icon(
                    icon,
                    color: Theme.of(context).iconTheme.color,
                    size: 24,
                  ),
                  if (showDot)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 18),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
              ),
              if (pro)
                Container(
                  margin: EdgeInsets.only(left: 8),
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFE3E3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Pro',
                    style: TextStyle(
                      color: Color(0xFFFF5A5A),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (ad)
                Container(
                  margin: EdgeInsets.only(left: 8),
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'AD',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _editTagDialog(BuildContext context, Map<String, dynamic> meta) async {
    final presetTags = ['--', '学习', '工作', '音乐'];
    String selectedTag = meta['tag'] ?? '--';
    TextEditingController addController = TextEditingController();
    List<String> allTags = [
      ...{
        ...presetTags,
        ..._metaDataList
            .map((m) => m['tag'])
            .where((t) => t != null && t != '--'),
      },
    ];
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                '编辑标签',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: selectedTag,
                    isExpanded: true,
                    onChanged: (value) {
                      if (value != null)
                        setStateDialog(() => selectedTag = value);
                    },
                    items: allTags
                        .map(
                          (tag) => DropdownMenuItem<String>(
                            value: tag,
                            child: Text(tag),
                          ),
                        )
                        .toList(),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: addController,
                          decoration: InputDecoration(hintText: '新标签'),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final newTag = addController.text.trim();
                          if (newTag.isNotEmpty && !allTags.contains(newTag)) {
                            setStateDialog(() {
                              allTags.add(newTag);
                              selectedTag = newTag;
                              addController.clear();
                            });
                          }
                        },
                        child: Text(
                          '+ 添加',
                          style: TextStyle(color: Colors.pink),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, selectedTag);
                  },
                  child: Text(
                    '保存',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((result) async {
      if (result != null && result is String) {
        setState(() {
          meta['tag'] = result;
        });
        await _saveMetaData();
      }
    });
  }

  Color _tagColor(String tag) {
    switch (tag) {
      case '学习':
        return Color(0xFF7ED6A7);
      case '工作':
        return Color(0xFF6EC1E4);
      case '音乐':
        return Color(0xFFB39DDB);
      case '--':
        return Color(0xFFEEEEEE);
      default:
        return Color(0xFFFF9800);
    }
  }

  Color _tagBgColor(String tag) {
    switch (tag) {
      case '学习':
        return Color(0x337ED6A7);
      case '工作':
        return Color(0x336EC1E4);
      case '音乐':
        return Color(0x33B39DDB);
      case '--':
        return Color(0x33EEEEEE);
      default:
        return Color(0x33BDBDBD);
    }
  }

  Future<void> _saveMetaData() async {
    final metaFile = await _getMetaFile();
    await metaFile.writeAsString(jsonEncode(_metaDataList));
  }

  Future<File> _getMetaFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/meta.json');
  }

  Map<String, dynamic>? _findMetaById(String id) {
    try {
      return _metaDataList.firstWhere((e) => e['id'] == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          '录音文件',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.color_lens,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () => _showThemeDialog(context),
            tooltip: '主题切换',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Theme.of(context).iconTheme.color),
            onPressed: _loadFiles,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'My',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        TextSpan(
                          text: 'Recorder',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Pro',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                '升级到专业版',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProPage()),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.checkroom,
                color: Theme.of(context).iconTheme.color,
              ),
              title: Text(
                '主题',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              onTap: () => _showThemeDialog(context),
            ),
            ListTile(
              leading: Icon(
                Icons.settings,
                color: Theme.of(context).iconTheme.color,
              ),
              title: Text(
                '设置',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsPage()),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.help_outline,
                color: Theme.of(context).iconTheme.color,
              ),
              title: Text(
                '常见问题',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FAQPage()),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.feedback,
                color: Theme.of(context).iconTheme.color,
              ),
              title: Text(
                '反馈',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FeedbackPage()),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.folder,
                color: Theme.of(context).iconTheme.color,
              ),
              title: Text(
                '查看应用内文件',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AppFilesPage()),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: loading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadFiles,
              color: Theme.of(context).colorScheme.primary,
              child: files.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.mic_off,
                            size: 80,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          SizedBox(height: 24),
                          Text(
                            '暂无录音文件',
                            style: TextStyle(
                              fontSize: 20,
                              color: Theme.of(context).colorScheme.onBackground,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '点击下方按钮开始录音',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _metaDataList.length,
                      itemBuilder: (context, index) {
                        final meta = _metaDataList[index];
                        final audioPath = meta['audioPath'] as String;
                        final fileName = audioPath.split('/').last;
                        final dotIdx = fileName.lastIndexOf('.');
                        final displayName =
                            meta['displayName'] ??
                            (dotIdx > 0
                                ? fileName.substring(0, dotIdx)
                                : fileName);
                        final ext = dotIdx > 0
                            ? fileName.substring(dotIdx)
                            : '';
                        final tag = meta['tag'] ?? '--';
                        final played = meta['played'] == true;
                        final modifiedTime = meta['created'] != null
                            ? DateTime.tryParse(meta['created']) ??
                                  DateTime.now()
                            : DateTime.now();
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              setState(() {
                                meta['played'] = true;
                              });
                              await _saveMetaData();
                              List<double> waveform = [];
                              try {
                                final dir =
                                    await getApplicationDocumentsDirectory();
                                final waveFile = File(
                                  '${dir.path}/${meta['wavePath']}',
                                );
                                if (await waveFile.exists()) {
                                  final content = await waveFile.readAsString();
                                  waveform = List<double>.from(
                                    jsonDecode(content),
                                  );
                                }
                              } catch (_) {}
                              final dir =
                                  await getApplicationDocumentsDirectory();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AudioPlayerPage(
                                    filePath: '${dir.path}/$audioPath',
                                    waveform: waveform,
                                    displayName: displayName,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outline.withOpacity(0.08),
                                ),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 左侧绿色渐变icon
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFFB7E7C2),
                                          Color(0xFF7ED6A7),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.graphic_eq,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  // 文件信息
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Text(
                                                    displayName,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 17,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onBackground,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // 红点
                                            if (!played)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                margin: EdgeInsets.only(
                                                  left: 6,
                                                  right: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              "${modifiedTime.year}/${modifiedTime.month.toString().padLeft(2, '0')}/${modifiedTime.day.toString().padLeft(2, '0')}  ${modifiedTime.hour.toString().padLeft(2, '0')}:${modifiedTime.minute.toString().padLeft(2, '0')}",
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.secondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            // 文件大小可选：如需显示需异步获取
                                            Spacer(),
                                            FutureBuilder<String>(
                                              future: _getAudioDuration(
                                                '${audioPath}',
                                              ),
                                              builder: (context, snapshot) {
                                                final duration =
                                                    snapshot.data ?? '00:00';
                                                return Text(
                                                  duration,
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.secondary,
                                                    fontSize: 13,
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 6),
                                        // 标签
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _tagBgColor(tag),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                tag,
                                                style: TextStyle(
                                                  color: _tagColor(tag),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 右侧操作按钮
                                  SizedBox(width: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.more_vert,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                          size: 22,
                                        ),
                                        onPressed: () =>
                                            _showFileMoreMenu(context, meta),
                                        tooltip: '更多',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(shape: BoxShape.circle),
        child: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RecordPage()),
            );
            // 录音完成后刷新文件列表
            _loadFiles();
          },
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          child: Icon(Icons.mic, size: 28),
        ),
      ),
    );
  }
}
