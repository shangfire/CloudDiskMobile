import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';

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

class Self {
  final int id;
  final int parentFolderId;
  final String name;
  final String path;
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

class File {
  final int id;
  final int parentFolderId;
  final String name;
  final int fileType;
  final String path;
  final int size;
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(
      debug: true // 开启调试模式
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const BrowsePage(),
    );
  }
}

class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  BrowsePageState createState() => BrowsePageState();
}

class BrowsePageState extends State<BrowsePage> {
  String? currentPath;
  int parentFolderID = 0;
  int currentFolderID = 1;
  List<Folder>? folders;
  List<File>? files;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData(currentFolderID);
  }

  Future<void> _fetchData(int folderID) async {
    setState(() {
      _loading = true;
    });
    final url = Uri.parse('http://182.92.66.72:8080/api/queryFolder');

    try {
      // 构建请求体
      Map<String, dynamic> requestBody = {
        'folderID': folderID,
      };

      // 发送 POST 请求
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json', // 设置请求头
        },
        body: jsonEncode(requestBody), // 将请求体编码为 JSON 字符串
      );

      if (response.statusCode == 200) {
        // 成功处理响应数据
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
          _loading = false; // 设置加载状态为 false
        });
      } else {
        // 处理错误响应
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      // 捕获异常并处理
      print('请求过程中发生错误: $e');
      setState(() {
        _loading = false; // 确保加载状态被重置
      });
    }
  }

  Future<void> showRenameDialog(BuildContext context, String name, int id, bool isFolder) {
    final TextEditingController textController = TextEditingController(text: name);

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // 用户点击背景时不会关闭对话框
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(hintText: "Enter new name"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Rename'),
              onPressed: () async {
                if (textController.text.isNotEmpty) {
                  await renameItem(context, textController.text, id, isFolder);
                  Navigator.of(context).pop(); // 关闭对话框
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> renameItem(BuildContext context, String newName, int id, bool isFolder) async {
    try {
      final url = isFolder
          ? Uri.parse('http://182.92.66.72:8080/api/renameFolder')
          : Uri.parse('http://182.92.66.72:8080/api/renameFile');

      final body = isFolder ? {'folderName': newName, 'folderID': id} : {'fileName': newName, 'fileID': id};

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (isFolder) {
          final folderIndex = folders?.indexWhere((folder) => folder.id == id);
          if (folderIndex != null && folderIndex >= 0) {
            setState(() {
              folders![folderIndex] = folders![folderIndex].copyWith(name: newName);
            });
          }
        } else {
          final fileIndex = files?.indexWhere((file) => file.id == id);
          if (fileIndex != null && fileIndex >= 0) {
            setState(() {
              files![fileIndex] = files![fileIndex].copyWith(name: newName);
            });
          }
        }

        // 成功处理后的逻辑，例如刷新列表
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Renamed successfully!')),
        );
        // 更新UI代码...
      } else {
        // 错误处理
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename. Please try again.')),
        );
      }
    } catch (e) {
      // 网络错误或其他异常处理
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred. Please check your connection and try again.')),
      );
    }
  }


  Future<void> showDeleteConfirmationDialog(BuildContext context, int id, bool isFolder) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // 用户点击背景时不会关闭对话框
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text(isFolder ? 'Are you sure you want to delete this folder?' : 'Are you sure you want to delete this file?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () async {
                await deleteItem(context, id, isFolder);
                Navigator.of(context).pop(); // 关闭对话框
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> deleteItem(BuildContext context, int id, bool isFolder) async {
    try {
      final url = isFolder
          ? Uri.parse('http://182.92.66.72:8080/api/deleteFolder')
          : Uri.parse('http://182.92.66.72:8080/api/deleteFile');

      final body = isFolder ? {'folderID': id} : {'fileID': id};

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) { // 通常204表示成功但没有内容返回
        // 更新本地数据模型
        if (isFolder) {
          setState(() {
            folders?.removeWhere((folder) => folder.id == id);
          });
        } else {
          setState(() {
            files?.removeWhere((file) => file.id == id);
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete. Please try again.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred. Please check your connection and try again.')),
      );
    }
  }

  void showCreateFolderDialog(BuildContext context, int parentFolderID) {
    final TextEditingController _controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New Folder'),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'Enter folder name'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () async {
                final String folderName = _controller.text.trim();
                if (folderName.isNotEmpty) {
                  final newFolder = await createFolder(folderName, parentFolderID);
                  if (newFolder != null) {
                    setState(() {
                      folders?.add(newFolder);
                      folders?.sort((a, b) => a.name.compareTo(b.name));
                    });
                  }

                  Navigator.of(context).pop(); // 关闭对话框
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Folder name cannot be empty')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<Folder?> createFolder(String folderName, int parentFolderID) async {
    final url = Uri.parse('http://182.92.66.72:8080/api/createFolder');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "folderName": folderName,
        "parentFolderID": parentFolderID,
      }),
    );

    if (response.statusCode == 200) {
      // 请求成功，可以刷新数据或显示成功消息
      print('Folder created successfully');
      final responseData = jsonDecode(response.body);
      final newFolder = Folder.fromJson(responseData);
      print('Folder created successfully: ${newFolder.name}');
      return newFolder;
    } else {
      // 请求失败，打印错误信息
      print('Failed to create folder: ${response.statusCode}');
    }
  }

  void showUploadFileDialog(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      PlatformFile file = result.files.first;
      final response = await uploadFile(file, currentFolderID);

      if (response != null) {
        // 更新本地状态和UI
        setState(() {
          files?.add(response);
          // 对列表进行排序，这里以文件名称为例
          files?.sort((a, b) => a.name.compareTo(b.name));
        });
      }
    } else {
      // 用户取消了文件选择
    }
  }

  Future<File?> uploadFile(PlatformFile file, int parentFolderID) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://182.92.66.72:8080/api/uploadFile'),
      );

      // 添加文件到请求中
      request.files.add(await http.MultipartFile.fromPath(
        'file', // 这是服务器端期待的字段名
        file.path!,
        contentType: MediaType.parse(lookupMimeType(file.path!) ?? 'application/octet-stream'),
      ));

      // 添加其他表单字段
      request.fields['parentFolderID'] = parentFolderID.toString();
      request.fields['fileSize'] = file.size.toString();

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final uploadedFile = File.fromJson(responseData);
        print('File uploaded successfully: ${uploadedFile.name}');
        return uploadedFile;
      } else {
        print('Failed to upload file: ${response.statusCode}');
        // throw Exception('Failed to upload file');
      }
    } catch (e) {
      print('Error during file upload: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload file: $e')),
      );
      return null;
    }
  }

  Future<void> downloadFile(int fileID) async {
    // 发送下载请求
    final response = await http.post(
      Uri.parse('http://182.92.66.72:8080/api/downloadFile'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"fileID": fileID}),
    );

    if (response.statusCode == 200) {
      final downloadUrl = jsonDecode(response.body)['downloadUrl'];

      // 获取保存路径
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception("Failed to get external storage directory.");
      }

      // 构建下载任务
      final taskId = await FlutterDownloader.enqueue(
        url: downloadUrl,
        savedDir: directory.path,
        fileName: "file_$fileID", // 可以根据实际情况调整文件名
        showNotification: true, // 显示下载进度通知
        openFileFromNotification: true, // 下载完成后打开文件
      );

      print('Download task created with ID: $taskId');
    } else {
      throw Exception('Failed to initiate download: ${response.statusCode}');
    }
  }

  void showDownloadConfirmationDialog(BuildContext context, int fileID) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Download File'),
          content: const Text('Do you want to download this file?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Download'),
              onPressed: () async {
                try {
                  await downloadFile(fileID);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Download started.')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to start download: $e')),
                  );
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void onTap(BuildContext context, int id, bool isFolder) {
    if (isFolder) {
      _fetchData(id);
    }
    else {
      showDownloadConfirmationDialog(context, id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // 返回上一层按钮，条件渲染
            if (parentFolderID != 0)
              IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () async {
                  // 处理返回上一层逻辑
                  await _fetchData(parentFolderID);
                },
              ),
            // 显示当前路径
            Expanded(
              child: Text(
                'Current Path: $currentPath',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchData(currentFolderID);
        },
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: (folders?.length ?? 0) + (files?.length ?? 0),
              itemBuilder: (context, index) {
                final isFolder = index < (folders?.length ?? 0);
                final item = isFolder ? folders![index] : files![index - (folders?.length ?? 0)];

                return Slidable(
                  key: ValueKey(item is Folder ? item.id : (item as File).id),
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (context) => showRenameDialog(context, item is Folder ? item.name : (item as File).name, item is Folder ? item.id : (item as File).id, isFolder),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        icon: Icons.edit,
                        label: 'Rename',
                      ),
                      SlidableAction(
                        onPressed: (context) => showDeleteConfirmationDialog(context, item is Folder ? item.id : (item as File).id, isFolder),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                        label: 'Delete',
                        ),
                    ],
                  ),
                  child: ListTile(
                    leading: isFolder ? const Icon(Icons.folder) : const Icon(Icons.insert_drive_file),
                    title: Text(item is Folder ? item.name : (item as File).name),
                    subtitle: isFolder ? null : Text('${(item as File).size} bytes'),
                    onTap: () => onTap(context, item is Folder ? (item as Folder).id : (item as File).id, isFolder),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            onPressed: () => showCreateFolderDialog(context, currentFolderID),
            tooltip: 'Add Folder',
            child: const Icon(Icons.create_new_folder),
          ),
          const SizedBox(height: 10), // 添加一些间距
          FloatingActionButton(
            onPressed: () => showUploadFileDialog(context),
            tooltip: 'Upload File',
            child: const Icon(Icons.file_upload),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
