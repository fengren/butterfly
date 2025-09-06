import 'package:butterfly/shared/services/share_handler_service.dart';
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
import 'services/auth_service.dart';
import 'debug_console_page.dart';
import 'package:http/http.dart' as http;
import 'shared/services/share_receiver_service.dart';
import 'shared/pages/share_detail_page.dart';
import 'shared/models/shared_content.dart';
import 'shared/models/share_content.dart';
import 'dart:async';
import 'models/unified_file_item.dart';
import 'services/unified_file_service.dart';
import 'shared/services/local_storage_service.dart';
import 'shared/widgets/enhanced_card/enhanced_card.dart';
import 'shared/models/unified_history.dart';
import 'shared/models/content_type.dart';

final shareHandlerService = ShareHandlerService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 注意：ShareHandlerService 将在 MyApp 初始化后启动
  await AuthService.login();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // 在下一帧初始化 ShareHandlerService，确保 MaterialApp 已完全创建
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔄 延迟初始化 ShareHandlerService');
      shareHandlerService.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return MaterialApp(
      navigatorKey: navigatorKey,
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
    if (name.endsWith('.mp3') ||
        name.endsWith('.m4a') ||
        name.endsWith('.wav')) {
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
  List<UnifiedFileItem> _unifiedFiles = [];
  bool loading = true;
  final Map<String, String> _durationCache = {};
  Map<FileSystemEntity, String> _fileTags = {};
  String _audioQuality = 'wav';
  final ShareReceiverService _shareReceiverService = ShareReceiverService();
  StreamSubscription? _shareSubscription;
  late final UnifiedFileService _unifiedFileService;

  @override
  void initState() {
    super.initState();
    _unifiedFileService = UnifiedFileService(LocalStorageServiceImpl());
    _loadFiles();
    _loadAudioQuality();
    _initializeShareReceiver();
  }

  Future<void> _initializeShareReceiver() async {
    try {
      _shareReceiverService.initialize();

      // 监听分享内容流
      _shareSubscription = _shareReceiverService.sharedContentStream.listen(
        (sharedContent) {
          _handleSharedContent(sharedContent);
        },
        onError: (error) {
          debugPrint('Share receiver error: $error');
        },
      );

      // 检查初始分享内容（应用启动时的分享）
      final initialContent = await _shareReceiverService
          .checkInitialSharedContent();
      if (initialContent != null) {
        _handleSharedContent(initialContent);
      }
    } catch (e) {
      debugPrint('Failed to initialize share receiver: $e');
    }
  }

  void _handleSharedContent(SharedContent sharedContent) async {
    debugPrint('========== Main: 接收到分享内容 ==========');
    debugPrint('Main: SharedContent ID: ${sharedContent.id}');
    debugPrint('Main: SharedContent 文本: ${sharedContent.text}');
    debugPrint(
      'Main: SharedContent 图片数量: ${sharedContent.images?.length ?? 0}',
    );

    try {
      // 首先保存SharedContent到LocalStorageService
      debugPrint('Main: 开始保存SharedContent到本地存储');
      final localStorageService = LocalStorageServiceImpl();
      await localStorageService.initialize();
      await localStorageService.saveSharedContent(sharedContent);
      debugPrint('Main: ✅ SharedContent保存成功');
    } catch (e) {
      debugPrint('Main: ❌ 保存SharedContent失败: $e');
    }

    // 创建ShareContent对象用于导航
    final shareContent = ShareContent(
      id: sharedContent.id,
      title: sharedContent.text?.isNotEmpty == true
          ? (sharedContent.text!.length > 50
                ? sharedContent.text!.substring(0, 50) + '...'
                : sharedContent.text!)
          : '分享内容',
      timestamp: DateTime.now(),
      messageCount: 1,
      imageCount: sharedContent.images?.length ?? 0,
      sourceApp: 'unknown',
      directoryPath: '/shared/${sharedContent.id}',
      originalContent: sharedContent,
    );

    debugPrint('Main: 创建的ShareContent标题: ${shareContent.title}');
    debugPrint('Main: 准备导航到ShareDetailPage');

    // 导航到分享详情页
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShareDetailPage(history: shareContent),
      ),
    );

    debugPrint('Main: ========== 导航完成 ==========');
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    _shareReceiverService.dispose();
    super.dispose();
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
          if (lower.endsWith('.mp3') ||
              lower.endsWith('.m4a') ||
              lower.endsWith('.wav')) {
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
      // 加载统一文件列表
      _unifiedFiles = await _unifiedFileService.loadAllFiles();

      // 保持原有的录音文件加载逻辑
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

  Future<void> _loadAudioQuality() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _audioQuality = prefs.getString('audio_quality') ?? 'wav';
    });
  }

  Future<void> _setAudioQuality(String quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audio_quality', quality);
    setState(() {
      _audioQuality = quality;
    });
  }

  Future<void> _renameFile(Map<String, dynamic> meta) async {
    final audioPath = meta['audioPath'] as String;
    final extension = '.mp3'; // 始终为 audio.mp3
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
    const duration = '--';
    _durationCache[filePath] = duration;
    return duration;
  }

  // 根据用户反馈：移除主题切换对话框方法

  void _showFileMoreMenu(BuildContext context, Map<String, dynamic> meta) {
    // 从meta中获取文件类型
    final fileType = meta['type'] as String?;
    final isAudioFile = fileType == 'audio';

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
              // 录音文件专有功能
              if (isAudioFile) ...[
                _buildMenuItem(
                  context,
                  Icons.text_snippet,
                  'AI转文字',
                  pro: true,
                  onTap: () async {
                    Navigator.pop(context);
                    await _handleAiTranscribe(meta);
                  },
                ),
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
              ],
              // 分享文件专有功能
              if (!isAudioFile) ...[
                _buildMenuItem(
                  context,
                  Icons.share,
                  '重新分享',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: 实现重新分享功能
                  },
                ),
                _buildMenuItem(
                  context,
                  Icons.info_outline,
                  '文件信息',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: 显示文件详细信息
                  },
                ),
              ],
              // 通用功能
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

  Future<void> _handleAiTranscribe(Map<String, dynamic> meta) async {
    final audioPath = meta['audioPath'] as String;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$audioPath');
    if (!await file.exists()) {
      DebugConsoleLog.log('[AI转文字] 音频文件不存在: ${file.path}');
      _showSnackBar('音频文件不存在');
      return;
    }
    final fileSize = await file.length();
    final fileName = file.path.split(Platform.pathSeparator).last;
    final ext = fileName.contains('.')
        ? fileName.substring(fileName.lastIndexOf('.'))
        : '';
    final displayName = meta['displayName'] ?? fileName;
    final filenameWithExt = displayName + ext;
    final formatType = ext.replaceFirst('.', '');
    final baseUrl = 'https://liangyi.29gpt.com';
    final createUrl = '$baseUrl/api/v1/audio-files/';
    final accessToken = await AuthService.getAccessToken();
    // 新增：如果已上传，直接查状态
    if (meta['upload_status'] == 'uploaded' && meta['audio_file_id'] != null) {
      final detailUrl = '$baseUrl/api/v1/audio-files/${meta['audio_file_id']}/';
      DebugConsoleLog.log('[AI转文字] 查询转写状态...\nGET $detailUrl');
      final detailResp = await http.get(
        Uri.parse(detailUrl),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      DebugConsoleLog.log(
        '[AI转文字] 状态查询响应: ' +
            detailResp.statusCode.toString() +
            '\n' +
            detailResp.body,
      );
      if (detailResp.statusCode == 200) {
        final detailData = jsonDecode(detailResp.body);
        // 写入 subtitle.json
        final subtitlePath = File('${dir.path}/${meta['subtitlePath']}');
        await subtitlePath.writeAsString(jsonEncode(detailData));
        // 新增：提取 summary 字段写入 summary.json
        if (detailData is Map &&
            detailData['data'] != null &&
            detailData['data']['summary'] != null) {
          final summary = detailData['data']['summary'];
          final summaryPath = File(
            '${dir.path}/${meta['audioPath']}'.replaceAll(
              RegExp(r'/[^/]+$'),
              '/summary.json',
            ),
          );
          await summaryPath.writeAsString(jsonEncode({'summary': summary}));
        }
        _showSnackBar('转写状态已写入subtitle.json和summary.json');
      } else {
        _showSnackBar('获取转写状态失败');
      }
      return;
    }
    try {
      // 1. 创建音频文件记录
      DebugConsoleLog.log(
        '[AI转文字] 创建音频文件记录...\nPOST $createUrl\nBody: ' +
            jsonEncode({
              'filename': filenameWithExt,
              'display_name': displayName,
              'file_size': fileSize,
              'format': formatType,
            }),
      );
      final createResp = await http.post(
        Uri.parse(createUrl),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'filename': filenameWithExt,
          'display_name': displayName,
          'file_size': fileSize,
          'format': formatType,
        }),
      );
      DebugConsoleLog.log(
        '[AI转文字] 创建音频文件响应: ' +
            createResp.statusCode.toString() +
            '\n' +
            createResp.body,
      );
      final createData = jsonDecode(createResp.body);
      if (createResp.statusCode != 201 || createData['code'] != 0) {
        _showSnackBar('创建音频文件失败');
        return;
      }
      final audioFileId = createData['data']['audio_file_id'];
      final uploadUrl = createData['data']['upload_url'];
      // 写入meta
      meta['audio_file_id'] = audioFileId;
      meta['upload_status'] = 'created';
      await _saveMetaData();
      // 2. 上传音频文件
      DebugConsoleLog.log(
        '[AI转文字] 上传音频文件...\nPUT $uploadUrl\nBody: <binary ${fileSize} bytes>',
      );
      final uploadResp = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': 'application/octet-stream'},
        body: file.readAsBytesSync(),
      );
      DebugConsoleLog.log(
        '[AI转文字] 上传响应: ' +
            uploadResp.statusCode.toString() +
            '\n' +
            uploadResp.body,
      );
      if (!(uploadResp.statusCode == 200 ||
          uploadResp.statusCode == 201 ||
          uploadResp.statusCode == 204)) {
        meta['upload_status'] = 'upload_failed';
        await _saveMetaData();
        _showSnackBar('音频上传失败');
        return;
      }
      meta['upload_status'] = 'uploaded';
      await _saveMetaData();
      // 3. 更新音频文件状态
      DebugConsoleLog.log(
        '[AI转文字] 更新音频文件状态...\nPUT $createUrl\nBody: ' +
            jsonEncode({'id': meta['audio_file_id'], 'status': 'uploaded'}),
      );
      final updateResp = await http.put(
        Uri.parse(createUrl),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'id': meta['audio_file_id'], 'status': 'uploaded'}),
      );
      DebugConsoleLog.log(
        '[AI转文字] 状态更新响应: ' +
            updateResp.statusCode.toString() +
            '\n' +
            updateResp.body,
      );
      final updateData = jsonDecode(updateResp.body);
      if (updateResp.statusCode == 200 && updateData['code'] == 0) {
        _showSnackBar('音频上传成功，已提交转写');
      } else {
        _showSnackBar('音频状态更新失败');
      }
    } catch (e) {
      DebugConsoleLog.log('[AI转文字] 异常: $e');
      _showSnackBar('AI转文字失败: $e');
    }
  }

  void _showSnackBar(String msg) {
    final ctx = context;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          // 根据用户反馈：移除主题切换按钮
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
            // 根据用户反馈：移除主题选择菜单项
            ListTile(
              leading: Icon(
                Icons.high_quality,
                color: Theme.of(context).iconTheme.color,
              ),
              title: Text(
                '音质选择',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              subtitle: Row(
                children: [
                  ChoiceChip(
                    label: Text('WAV'),
                    selected: _audioQuality == 'wav',
                    onSelected: (v) => _setAudioQuality('wav'),
                  ),
                  SizedBox(width: 12),
                  ChoiceChip(
                    label: Text('AAC'),
                    selected: _audioQuality == 'aac',
                    onSelected: (v) => _setAudioQuality('aac'),
                  ),
                ],
              ),
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
            ListTile(
              leading: Icon(
                Icons.bug_report,
                color: Theme.of(context).iconTheme.color,
              ),
              title: Text(
                '调试控制台',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DebugConsolePage()),
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
              child: _unifiedFiles.isEmpty
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
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      itemCount: _unifiedFiles.length,
                      itemBuilder: (context, index) {
                        final unifiedFile = _unifiedFiles[index];

                        // 统一的显示属性
                        final displayName = unifiedFile.title;
                        final tag = unifiedFile.type == FileType.audio
                            ? (unifiedFile.metadata['tag'] ?? '--')
                            : '分享';
                        final played = unifiedFile.type == FileType.audio
                            ? (unifiedFile.metadata['played'] == true)
                            : true;
                        final modifiedTime = unifiedFile.createdAt;

                        return Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              if (unifiedFile.type == FileType.audio) {
                                // 录音文件：更新播放状态并跳转到音频播放页面
                                setState(() {
                                  unifiedFile.metadata['played'] = true;
                                });
                                await _saveMetaData();

                                List<double> waveform = [];
                                try {
                                  final dir =
                                      await getApplicationDocumentsDirectory();
                                  final waveFile = File(
                                    '${dir.path}/${unifiedFile.wavePath ?? ''}',
                                  );
                                  if (await waveFile.exists()) {
                                    final content = await waveFile
                                        .readAsString();
                                    waveform = List<double>.from(
                                      jsonDecode(content),
                                    );
                                  }
                                } catch (_) {}

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AudioPlayerPage(
                                      filePath: unifiedFile.absolutePath,
                                      waveform: waveform,
                                      displayName: displayName,
                                    ),
                                  ),
                                );
                              } else if (unifiedFile.type == FileType.share) {
                                // 分享文件：跳转到分享详情页面
                                final shareContent = ShareContent(
                                  id: unifiedFile.id,
                                  title: unifiedFile.title,
                                  timestamp: unifiedFile.createdAt,
                                  messageCount: 1,
                                  imageCount: 0,
                                  sourceApp: '未知应用',
                                  directoryPath: unifiedFile.absolutePath,
                                );

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ShareDetailPage(history: shareContent),
                                  ),
                                );
                              }
                            },
                            child: EnhancedCard(
                              item: _convertToUnifiedHistory(
                                unifiedFile,
                                played,
                                tag,
                              ),
                              animationDelay: index * 50, // 交错动画延迟
                              onTap: () {
                                // 保持原有的点击逻辑
                                if (unifiedFile.type == FileType.audio) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AudioPlayerPage(
                                        filePath: unifiedFile.absolutePath,
                                        waveform: [],
                                        displayName: displayName,
                                      ),
                                    ),
                                  );
                                } else if (unifiedFile.type == FileType.share) {
                                  final shareContent = ShareContent(
                                    id: unifiedFile.id,
                                    title: unifiedFile.title,
                                    timestamp: unifiedFile.createdAt,
                                    messageCount: 1,
                                    imageCount: 0,
                                    sourceApp: '未知应用',
                                    directoryPath: unifiedFile.absolutePath,
                                  );

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ShareDetailPage(
                                        history: shareContent,
                                      ),
                                    ),
                                  );
                                }
                              },
                              onLongPress: () => _showFileMoreMenu(context, {
                                ...unifiedFile.metadata,
                                'type': unifiedFile.type == FileType.audio
                                    ? 'audio'
                                    : 'shared',
                              }),
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

  // 转换UnifiedFileItem为UnifiedHistory
  UnifiedHistory _convertToUnifiedHistory(
    UnifiedFileItem file,
    bool played,
    String tag,
  ) {
    return UnifiedHistory(
      id: file.id,
      title: file.title,
      description: file.title,
      contentType: file.type == FileType.audio
          ? ContentType.audio
          : ContentType.share,
      filePath: file.absolutePath,
      timestamp: file.createdAt,
      metadata: {
        ...file.metadata,
        'isRead': played,
        'tags': [tag],
        'shareSource': file.type == FileType.share
            ? {'appName': '分享应用', 'packageName': 'com.share.app'}
            : null,
      },
    );
  }
}
