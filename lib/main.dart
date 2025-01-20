import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

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

void main() {
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
  int _selectedIndex = 0;
  static final List<Widget> _pages = <Widget>[
    const BrowsePage(),
    const UploadPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Browse',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload),
            label: 'Upload',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            onPressed: () => showCreateFolderDialog(context, currentParentFolderId),
            tooltip: 'Add Folder',
            child: const Icon(Icons.create_new_folder),
          ),
          const SizedBox(height: 10), // 添加一些间距
          FloatingActionButton(
            onPressed: () => {},
            tooltip: 'Upload File',
            child: const Icon(Icons.file_upload),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
  int? parentFolderID;
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

  void onFolderTap(int folderID) {
    _fetchData(folderID);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folder and File List'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchData(currentFolderID);
        },
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          ListTile(
            title: Text('Current Path: $currentPath'),
          ),
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
                    onTap: isFolder ? () => onFolderTap((item as Folder).id) : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    )
    );
  }
}

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  UploadPageState createState() => UploadPageState();
}

class UploadPageState extends State<UploadPage> {
  final _formKey = GlobalKey<FormState>();
  String? _title;
  String? _content;
  List<PlatformFile>? _files;

  Future<void> _uploadData() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      var request = http.MultipartRequest('POST', Uri.parse('http://47.93.220.11:8080/upload'));

      // 添加表单字段
      request.fields['title'] = _title!;
      request.fields['content'] = _content!;

      // 添加文件
      if (_files != null) {
        for (var file in _files!) {
          request.files.add(await http.MultipartFile.fromPath('files[]', file.path!));
        }
      }

      // 发送请求
      var response = await request.send();

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('上传成功！')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('上传失败！')));
        }
      }
    }
  }

  Future<void> _pickFiles() async {
    // 请求权限
    var status = await Permission.storage.request();
    if (status.isGranted) {
      // 权限被授予后，选择文件
      _files = (await FilePicker.platform.pickFiles(allowMultiple: true))?.files;
      setState(() {});
    } else {
      // 权限未被授予
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请允许访问文件')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Page'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return '请输入标题';
                  }
                  return null;
                },
                onSaved: (value) {
                  _title = value;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Content'),
                validator: (value) {
                  if (value!.isEmpty) {
                    return '请输入内容';
                  }
                  return null;
                },
                onSaved: (value) {
                  _content = value;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickFiles,
                child: const Text('选择文件'),
              ),
              if (_files != null)
                ..._files!.map((file) => Text(file.name)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _uploadData,
                child: const Text('上传'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}