// 依赖说明：
// http              - 发送 HTTP 请求（GET/POST/multipart）
// file_picker       - 调起系统文件选择器，获取本地文件路径
// flutter_slidable  - 列表项左滑/右滑操作面板
// mime / http_parser - 根据文件扩展名推断 MIME 类型，用于上传时设置 Content-Type
// path_provider     - 获取设备存储路径（外部存储目录）
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────
// 数据模型：对应后端 /api/queryFolder 的响应结构
// {
//   "self":    { 当前文件夹信息 },
//   "folders": [ 子文件夹列表 ],
//   "files":   [ 当前文件夹下的文件列表 ]
// }
// ─────────────────────────────────────────────

/// 查询文件夹接口的完整响应
class QueryFolderData {
  final Self self;
  final List<Folder> folders;
  final List<File> files;

  QueryFolderData({
    required this.self,
    required this.folders,
    required this.files,
  });

  factory QueryFolderData.fromJson(Map<String, dynamic> json) {
    return QueryFolderData(
      self: Self.fromJson(json['self']),
      folders: List<Folder>.from(json['folders'].map((x) => Folder.fromJson(x))),
      files: List<File>.from(json['files'].map((x) => File.fromJson(x))),
    );
  }
}

/// 当前文件夹自身的信息（用于获取路径、父级 ID 等导航数据）
class Self {
  final int id;
  final int parentFolderId; // 父文件夹 ID，根目录时为 0
  final String name;
  final String path;        // 完整路径字符串，显示在 AppBar
  final DateTime createdAt;
  final DateTime updatedAt;

  Self({
    required this.id,
    required this.parentFolderId,
    required this.name,
    required this.path,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Self.fromJson(Map<String, dynamic> json) {
    return Self(
      id: json['id'],
      parentFolderId: json['parentFolderId'],
      name: json['name'],
      path: json['path'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

/// 文件夹数据模型
class Folder {
  final int id;
  final int parentFolderId;
  final String name;
  final String path;
  final DateTime createdAt;
  final DateTime updatedAt;

  Folder({
    required this.id,
    required this.parentFolderId,
    required this.name,
    required this.path,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'],
      parentFolderId: json['parentFolderId'],
      name: json['name'],
      path: json['path'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  // 用于重命名后在本地更新列表，避免重新请求整个列表
  Folder copyWith({
    int? id,
    int? parentFolderId,
    String? name,
    String? path,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Folder(
      id: id ?? this.id,
      parentFolderId: parentFolderId ?? this.parentFolderId,
      name: name ?? this.name,
      path: path ?? this.path,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 文件数据模型
class File {
  final int id;
  final int parentFolderId;
  final String name;
  final int fileType;
  final String path;
  final int size;     // 文件大小，单位：字节
  final DateTime createdAt;
  final DateTime updatedAt;

  File({
    required this.id,
    required this.parentFolderId,
    required this.name,
    required this.fileType,
    required this.path,
    required this.size,
    required this.createdAt,
    required this.updatedAt,
  });

  factory File.fromJson(Map<String, dynamic> json) {
    return File(
      id: json['id'],
      parentFolderId: json['parentFolderId'],
      name: json['name'],
      fileType: json['fileType'],
      path: json['path'],
      size: json['size'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  // 用于重命名后在本地更新列表，避免重新请求整个列表
  File copyWith({
    int? id,
    int? parentFolderId,
    String? name,
    int? fileType,
    String? path,
    int? size,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return File(
      id: id ?? this.id,
      parentFolderId: parentFolderId ?? this.parentFolderId,
      name: name ?? this.name,
      fileType: fileType ?? this.fileType,
      path: path ?? this.path,
      size: size ?? this.size,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ─────────────────────────────────────────────
// 应用入口 & 顶层 Widget
// ─────────────────────────────────────────────

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cloud Disk',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainPage(),
    );
  }
}

/// 主页面，目前只是 BrowsePage 的壳，后续可在此添加底部导航栏等
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: BrowsePage(),
    );
  }
}

// ─────────────────────────────────────────────
// 核心页面：文件/文件夹浏览
// ─────────────────────────────────────────────

/// 文件浏览页面（有状态），负责展示当前目录内容并处理所有用户操作
class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  BrowsePageState createState() => BrowsePageState();
}

class BrowsePageState extends State<BrowsePage> {
  String? currentPath;
  int parentFolderID = 0;   // 父目录 ID；为 0 表示已在根目录，隐藏返回按钮
  int currentFolderID = 1;  // 当前目录 ID；初始值 1 表示根目录
  List<Folder>? folders;
  List<File>? files;
  bool _loading = true;
  bool _uploading = false;      // 上传进行中
  String _uploadingName = '';   // 正在上传的文件名
  bool _downloading = false;
  String _downloadingName = '';
  double _downloadProgress = 0.0; // 0.0~1.0，-1 表示进度未知

  static const String _baseUrl = 'https://shangfire.cn';

  @override
  void initState() {
    super.initState();
    _fetchData(currentFolderID);
  }

  // ── 工具函数 ──────────────────────────────

  /// 格式化文件大小，自动选择合适的单位
  String _formatFileSize(int size) {
    if (size == 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (math.log(size) / math.log(1024)).floor();
    return '${(size / math.pow(1024, i)).toStringAsFixed(2)} ${units[i]}';
  }

  /// 获取下载保存目录
  /// Android：app 专属外部存储（无需额外权限），iOS：Documents 目录
  Future<io.Directory> _getDownloadDirectory() async {
    if (io.Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir != null) return dir;
    }
    return getApplicationDocumentsDirectory();
  }

  // ── 网络请求 ──────────────────────────────

  /// 请求指定文件夹的内容，成功后更新状态刷新 UI
  Future<void> _fetchData(int folderID) async {
    setState(() { _loading = true; });
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/queryFolder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'folderID': folderID}),
      );
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final data = QueryFolderData.fromJson(jsonResponse);
        data.folders.sort((a, b) => a.name.compareTo(b.name));
        data.files.sort((a, b) => a.name.compareTo(b.name));
        setState(() {
          currentPath = data.self.path;
          parentFolderID = data.self.parentFolderId;
          currentFolderID = data.self.id;
          folders = data.folders;
          files = data.files;
          _loading = false;
        });
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('请求过程中发生错误: $e');
      if (mounted) setState(() { _loading = false; });
    }
  }

  // ── 重命名 ────────────────────────────────

  /// 弹出重命名对话框，预填当前名称，确认后调用 renameItem
  Future<void> showRenameDialog(BuildContext context, String name, int id, bool isFolder) {
    final textController = TextEditingController(text: name);
    // 在 await 前保存 messenger，避免 async gap 后 context 失效
    final messenger = ScaffoldMessenger.of(context);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('重命名'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(hintText: '输入新名称'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('确认'),
              onPressed: () async {
                if (textController.text.isNotEmpty) {
                  await renameItem(messenger, textController.text, id, isFolder);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// 调用重命名接口，成功后用 copyWith 本地更新列表，无需重新拉取整个目录
  Future<void> renameItem(ScaffoldMessengerState messenger, String newName, int id, bool isFolder) async {
    try {
      final url = isFolder
          ? Uri.parse('$_baseUrl/api/renameFolder')
          : Uri.parse('$_baseUrl/api/renameFile');
      final body = isFolder
          ? {'folderName': newName, 'folderID': id}
          : {'fileName': newName, 'fileID': id};

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (isFolder) {
          final idx = folders?.indexWhere((f) => f.id == id);
          if (idx != null && idx >= 0 && mounted) {
            setState(() { folders![idx] = folders![idx].copyWith(name: newName); });
          }
        } else {
          final idx = files?.indexWhere((f) => f.id == id);
          if (idx != null && idx >= 0 && mounted) {
            setState(() { files![idx] = files![idx].copyWith(name: newName); });
          }
        }
        messenger.showSnackBar(const SnackBar(content: Text('重命名成功')));
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('重命名失败，请重试')));
      }
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('网络错误，请检查连接')));
    }
  }

  // ── 删除 ──────────────────────────────────

  /// 弹出删除确认对话框，防止误操作
  Future<void> showDeleteConfirmationDialog(BuildContext context, int id, bool isFolder) {
    final messenger = ScaffoldMessenger.of(context);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text(isFolder ? '确定要删除该文件夹吗？' : '确定要删除该文件吗？'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('删除'),
              onPressed: () async {
                await deleteItem(messenger, id, isFolder);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// 调用删除接口，成功后从本地列表移除
  Future<void> deleteItem(ScaffoldMessengerState messenger, int id, bool isFolder) async {
    try {
      final url = isFolder
          ? Uri.parse('$_baseUrl/api/deleteFolder')
          : Uri.parse('$_baseUrl/api/deleteFile');
      final body = isFolder ? {'folderID': id} : {'fileID': id};

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            if (isFolder) {
              folders?.removeWhere((f) => f.id == id);
            } else {
              files?.removeWhere((f) => f.id == id);
            }
          });
        }
        messenger.showSnackBar(const SnackBar(content: Text('删除成功')));
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
      }
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('网络错误，请检查连接')));
    }
  }

  // ── 新建文件夹 ────────────────────────────

  /// 弹出输入框让用户填写新文件夹名称，确认后调用 createFolder
  void showCreateFolderDialog(BuildContext context, int parentFolderID) {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('新建文件夹'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '输入文件夹名称'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('创建'),
              onPressed: () async {
                final folderName = controller.text.trim();
                if (folderName.isNotEmpty) {
                  final newFolder = await createFolder(messenger, folderName, parentFolderID);
                  if (newFolder != null && mounted) {
                    setState(() {
                      folders?.add(newFolder);
                      folders?.sort((a, b) => a.name.compareTo(b.name));
                    });
                  }
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                } else {
                  messenger.showSnackBar(const SnackBar(content: Text('文件夹名称不能为空')));
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// 调用新建文件夹接口，返回后端创建好的 Folder 对象（含 ID）
  Future<Folder?> createFolder(ScaffoldMessengerState messenger, String folderName, int parentFolderID) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/createFolder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'folderName': folderName, 'parentFolderID': parentFolderID}),
      );
      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        return Folder.fromJson(responseData);
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('创建文件夹失败，请重试')));
        return null;
      }
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('网络错误，请检查连接')));
      return null;
    }
  }

  // ── 上传文件 ──────────────────────────────

  /// 调起系统文件选择器，用户选择文件后上传到当前目录
  void showUploadFileDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      final file = result.files.first;
      setState(() { _uploading = true; _uploadingName = file.name; });
      final uploaded = await uploadFile(messenger, file, currentFolderID);
      if (mounted) {
        setState(() { _uploading = false; _uploadingName = ''; });
        if (uploaded != null) {
          setState(() {
            files?.add(uploaded);
            files?.sort((a, b) => a.name.compareTo(b.name));
          });
        }
      }
    }
  }

  void showUploadFolderDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null || !mounted) return;

    final dir = io.Directory(dirPath);
    final folderName = dirPath.split(io.Platform.pathSeparator).last;

    // 构建预览列表（含根目录节点）
    final flatList = <Map<String, dynamic>>[];
    flatList.add({'name': folderName, 'isFolder': true, 'depth': 0});
    await _buildPreviewList(dir, 1, flatList);

    final folderCount = flatList.where((e) => e['isFolder'] == true).length;
    final fileCount   = flatList.where((e) => e['isFolder'] == false).length;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: this.context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('准备上传'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$folderCount 个文件夹，$fileCount 个文件',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[50],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: flatList.length,
                itemBuilder: (_, i) {
                  final item = flatList[i];
                  final depth = item['depth'] as int;
                  final isFolder = item['isFolder'] as bool;
                  return Padding(
                    padding: EdgeInsets.only(left: depth * 16.0 + 8, top: 3, bottom: 3, right: 8),
                    child: Row(
                      children: [
                        Icon(isFolder ? Icons.folder : Icons.insert_drive_file,
                            size: 15, color: isFolder ? Colors.amber : Colors.blueGrey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(item['name'] as String,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('确认上传')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() { _uploading = true; _uploadingName = folderName; });
    try {
      // 先在当前目录创建根文件夹，再递归上传内容
      final rootFolder = await createFolder(messenger, folderName, currentFolderID);
      if (rootFolder != null) {
        await _uploadDirectoryContents(messenger, dir, rootFolder.id);
      }
      if (mounted) await _fetchData(currentFolderID);
    } finally {
      if (mounted) setState(() { _uploading = false; _uploadingName = ''; });
    }
  }

  Future<void> _buildPreviewList(io.Directory dir, int depth, List<Map<String, dynamic>> result) async {
    final entities = await dir.list().toList();
    entities.sort((a, b) {
      final aIsDir = a is io.Directory;
      final bIsDir = b is io.Directory;
      if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
      return a.path.compareTo(b.path);
    });
    for (final entity in entities) {
      final name = entity.path.split(io.Platform.pathSeparator).last;
      final isFolder = entity is io.Directory;
      result.add({'name': name, 'isFolder': isFolder, 'depth': depth});
      if (entity is io.Directory) {
        await _buildPreviewList(entity, depth + 1, result);
      }
    }
  }

  Future<void> _uploadDirectoryContents(
      ScaffoldMessengerState messenger, io.Directory dir, int parentFolderID) async {
    final entities = await dir.list().toList();
    for (final entity in entities) {
      if (entity is io.Directory) {
        final name = entity.path.split(io.Platform.pathSeparator).last;
        if (mounted) setState(() { _uploadingName = name; });
        final newFolder = await createFolder(messenger, name, parentFolderID);
        if (newFolder != null) {
          await _uploadDirectoryContents(messenger, entity, newFolder.id);
        }
      }
    }
    for (final entity in entities) {
      if (entity is io.File) {
        final name = entity.path.split(io.Platform.pathSeparator).last;
        if (mounted) setState(() { _uploadingName = name; });
        await _uploadFileFromPath(messenger, entity.path, name, parentFolderID);
      }
    }
  }

  Future<void> _uploadFileFromPath(
      ScaffoldMessengerState messenger, String filePath, String fileName, int parentFolderID) async {
    try {
      final fileSize = await io.File(filePath).length();
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/uploadFile'));
      request.files.add(await http.MultipartFile.fromPath(
        'file', filePath,
        contentType: MediaType.parse(lookupMimeType(filePath) ?? 'application/octet-stream'),
      ));
      request.fields['parentFolderID'] = parentFolderID.toString();
      request.fields['fileSize'] = fileSize.toString();
      final streamedResponse = await request.send();
      await http.Response.fromStream(streamedResponse);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('上传失败: $fileName - $e')));
    }
  }

  /// 以 multipart/form-data 格式上传文件
  Future<File?> uploadFile(ScaffoldMessengerState messenger, PlatformFile file, int parentFolderID) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/uploadFile'),
      );
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path!,
        contentType: MediaType.parse(lookupMimeType(file.path!) ?? 'application/octet-stream'),
      ));
      request.fields['parentFolderID'] = parentFolderID.toString();
      request.fields['fileSize'] = file.size.toString();

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        return File.fromJson(responseData);
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('上传失败，请重试')));
        return null;
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('上传失败: $e')));
      return null;
    }
  }

  // ── 下载文件 ──────────────────────────────

  Future<void> downloadFile(BuildContext context, int fileID, String fileName) async {
    setState(() { _downloading = true; _downloadingName = fileName; _downloadProgress = 0.0; });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final request = http.Request('GET', Uri.parse('$_baseUrl/api/downloadFile?fileID=$fileID'));
      final streamedResponse = await http.Client().send(request);
      if (streamedResponse.statusCode == 200) {
        final contentLength = streamedResponse.contentLength;
        final dir = await _getDownloadDirectory();
        final file = io.File('${dir.path}/$fileName');
        final sink = file.openWrite();
        int received = 0;
        await for (final chunk in streamedResponse.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (contentLength != null && contentLength > 0 && mounted) {
            setState(() { _downloadProgress = received / contentLength; });
          }
        }
        await sink.close();
        messenger.showSnackBar(SnackBar(content: Text('已保存: ${file.path}')));
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('下载失败，请重试')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('下载失败: $e')));
    } finally {
      if (mounted) setState(() { _downloading = false; _downloadingName = ''; _downloadProgress = 0.0; });
    }
  }

  /// 下载文件夹（ZIP 打包），进度通过顶部 banner 展示
  Future<void> downloadFolder(BuildContext context, int folderID, String folderName) async {
    setState(() { _downloading = true; _downloadingName = '$folderName.zip'; });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/downloadFolder?folderID=$folderID'),
      );
      if (response.statusCode == 200) {
        final dir = await _getDownloadDirectory();
        final file = io.File('${dir.path}/$folderName.zip');
        await file.writeAsBytes(response.bodyBytes);
        messenger.showSnackBar(SnackBar(content: Text('已保存: ${file.path}')));
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('下载失败，请重试')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('下载失败: $e')));
    } finally {
      if (mounted) setState(() { _downloading = false; _downloadingName = ''; });
    }
  }

  /// 下载前弹出确认对话框（文件下载是触发性操作，确认防止误触）
  void showDownloadConfirmationDialog(BuildContext context, int fileID, String fileName) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('下载文件'),
          content: Text('确认下载「$fileName」？'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('下载'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // 使用外层 context（页面级别），而非 dialog 的 context
                downloadFile(context, fileID, fileName);
              },
            ),
          ],
        );
      },
    );
  }

  // ── 粘贴文本 ──────────────────────────────

  void showPasteTextDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('剪贴板中没有文本内容')));
      return;
    }
    final now = DateTime.now();
    String pad(int n) => n.toString().padLeft(2, '0');
    final defaultName =
        '${now.year}-${pad(now.month)}-${pad(now.day)}_${pad(now.hour)}-${pad(now.minute)}-${pad(now.second)}.txt';
    final controller = TextEditingController(text: defaultName);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('粘贴文本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('文件名', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            TextField(controller: controller, decoration: const InputDecoration(isDense: true)),
            const SizedBox(height: 12),
            const Text('内容预览', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Text(
                  text.length > 300 ? '${text.substring(0, 300)}...' : text,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final filename = controller.text.trim().isEmpty ? defaultName : controller.text.trim();
              final tempFile = io.File('${io.Directory.systemTemp.path}/$filename');
              await tempFile.writeAsString(text);
              await _uploadFileFromPath(messenger, tempFile.path, filename, currentFolderID);
              await tempFile.delete();
              if (mounted) await _fetchData(currentFolderID);
            },
            child: const Text('确定上传'),
          ),
        ],
      ),
    );
  }

  // ── 列表点击 ──────────────────────────────

  /// 文件夹 → 进入该目录；文件 → 弹出下载确认框
  void onTap(BuildContext context, dynamic item, bool isFolder) {
    if (isFolder) {
      _fetchData((item as Folder).id);
    } else {
      final file = item as File;
      showDownloadConfirmationDialog(context, file.id, file.name);
    }
  }

  // ── UI 构建 ───────────────────────────────

  Widget _buildProgressBanner(String message, {double? progress}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.blue[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14, height: 14,
                child: progress != null
                    ? CircularProgressIndicator(value: progress, strokeWidth: 2)
                    : const CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                ),
              ),
              if (progress != null)
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (parentFolderID != 0)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _fetchData(parentFolderID),
              ),
            Expanded(
              child: Text(
                currentPath ?? '',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste),
            tooltip: '粘贴文本',
            onPressed: () => showPasteTextDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchData(currentFolderID),
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_uploading)
                  _buildProgressBanner('正在上传: $_uploadingName'),
                if (_downloading)
                  _buildProgressBanner(
                    '正在下载: $_downloadingName',
                    progress: _downloadProgress > 0 ? _downloadProgress : null,
                  ),
                Expanded(
                  child: ListView.builder(
                    // 文件夹在前，文件在后，合并为一个列表
                    itemCount: (folders?.length ?? 0) + (files?.length ?? 0),
                    itemBuilder: (context, index) {
                      final isFolder = index < (folders?.length ?? 0);
                      final item = isFolder
                          ? folders![index]
                          : files![index - (folders?.length ?? 0)];
                      final itemId = item is Folder ? item.id : (item as File).id;
                      final itemName = item is Folder ? item.name : (item as File).name;

                      return Slidable(
                        key: ValueKey(itemId),
                        endActionPane: ActionPane(
                          motion: const ScrollMotion(),
                          children: [
                            // 下载：文件夹打包 ZIP，文件弹确认框
                            SlidableAction(
                              onPressed: (_) => isFolder
                                  ? downloadFolder(context, itemId, itemName)
                                  : showDownloadConfirmationDialog(context, itemId, itemName),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              icon: Icons.download,
                              label: '下载',
                            ),
                            SlidableAction(
                              onPressed: (_) => showRenameDialog(context, itemName, itemId, isFolder),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              icon: Icons.edit,
                              label: '重命名',
                            ),
                            SlidableAction(
                              onPressed: (_) => showDeleteConfirmationDialog(context, itemId, isFolder),
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              icon: Icons.delete,
                              label: '删除',
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: isFolder
                              ? const Icon(Icons.folder)
                              : const Icon(Icons.insert_drive_file),
                          title: Text(itemName),
                          subtitle: isFolder ? null : Text(_formatFileSize((item as File).size)),
                          onTap: () => onTap(context, item, isFolder),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      ),
      // 右下角三个浮动按钮：新建文件夹 / 上传文件夹 / 上传文件
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            onPressed: () => showCreateFolderDialog(context, currentFolderID),
            tooltip: '新建文件夹',
            child: const Icon(Icons.create_new_folder),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () => showUploadFolderDialog(context),
            tooltip: '上传文件夹',
            child: const Icon(Icons.drive_folder_upload),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () => showUploadFileDialog(context),
            tooltip: '上传文件',
            child: const Icon(Icons.file_upload),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
