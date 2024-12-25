import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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
  int? currentFolderID;
  List<Folder>? folders;
  List<File>? files;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
    });
    final url = Uri.parse('http://182.92.66.72:8080/api/queryFolder');

    try {
      // 构建请求体
      Map<String, dynamic> requestBody = {
        'folderID': 1,
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
        final jsonResponse = json.decode(response.body);
        final data = QueryFolderData.fromJson(jsonResponse);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folder and File List'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          ListTile(
            title: Text('Current Path: $currentPath'),
            subtitle: Text('Parent Folder ID: $parentFolderID'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: (folders?.length ?? 0) + (files?.length ?? 0),
              itemBuilder: (context, index) {
                if (index < (folders?.length ?? 0)) {
                  final folder = folders![index];
                  return ListTile(
                    title: Text(folder.name),
                    subtitle: Text(folder.path),
                  );
                } else {
                  final fileIndex = index - (folders?.length ?? 0);
                  final file = files![fileIndex];
                  return ListTile(
                    title: Text(file.name),
                    subtitle: Text('${file.size} bytes'),
                  );
                }
              },
            ),
          ),
        ],
      ),
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