import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart' as f;
import 'flutter_saf_platform_interface.dart';
import 'package:flutter/services.dart';


final class _DirContent extends Struct {
  external Pointer<Pointer<f.Utf8>> folders;
  @Int32()
  external int folderCount;
  external Pointer<Pointer<f.Utf8>> files;
  @Int32()
  external int fileCount;
}

final class _DirInfo extends Struct {
  external Pointer<f.Utf8> path;
  @Int32()
  external int descriptor;
}

final class _FileContent extends Struct {
  external Pointer<Uint8> data;
  @Int32()
  external int  size;
}

class _AndroidNativePathFuncProxy {
  //throws uninitialized exception on non-android platform when trying to call these
  late final int Function(int descriptor) checkDescriptor;
  late final Pointer<_DirContent>? Function(int descriptor) _listDir;
  late final Pointer<_DirInfo>? Function(Pointer<f.Utf8> path) _openDir;
  late final int Function(int descriptor) getParent;
  late final Pointer<_DirInfo>? Function(Pointer<f.Utf8> path, bool recursive) _createDir;
  late final Pointer<_DirInfo>? Function(int descriptor, Pointer<f.Utf8> path) _renameDir;
  late final int Function(int descriptor, bool recursive) deleteDir;
  late final int Function(int descriptor) getFileSize;
  late final Pointer<_DirInfo>? Function(Pointer<f.Utf8> path, bool recursive) _createFile;
  late final Pointer<_DirInfo>? Function(int descriptor, Pointer<f.Utf8> path, bool copy) _renameFile;
  late final int Function(int descriptor) deleteFile;
  late final Pointer<_FileContent> Function(int d) _fileReadAllBytes;
  late final int Function(int d, Pointer<Uint8> p, int s, int a) _fileWriteAllBytes;

  late final int Function(int descriptor, int mode) _openFile;
  late final int Function(int d) closeFile;
  late final int Function(int d) flushFile;
  late final int Function(int d) fileSize;
  late final int Function(int d) ftell;
  late final int Function(int d) readByte;
  late final int Function(int d, Pointer<Uint8> b, int c) readBytes;
  late final int Function(int d, int b) writeByte;
  late final int Function(int d, Pointer<Uint8> b, int c) writeBytes;
  late final int Function(int d, int p) fseek;

  late final Pointer<Void> Function(int) malloc;
  late final Pointer<NativeFinalizerFunction> nativeFree;
  late final void Function(Pointer<Void>) free;

  _AndroidNativePathFuncProxy(){
    if(Platform.isAndroid) {
      final DynamicLibrary nativeLib = DynamicLibrary.open('libflutter-saf.so');

      malloc = nativeLib.lookup<NativeFunction<Pointer<Void> Function(Int32)>>('_malloc').asFunction();
      nativeFree = nativeLib.lookup<NativeFunction<Void Function(Pointer<Void>)>>('_free');
      free = nativeFree.asFunction();

      _listDir = nativeLib.lookup<NativeFunction<Pointer<_DirContent>? Function(Int32)>>('listDir').asFunction();
      _openDir = nativeLib.lookup<NativeFunction<Pointer<_DirInfo>? Function(Pointer<f.Utf8>)>>('openDir').asFunction();
      getParent = nativeLib.lookup<NativeFunction<Int32 Function(Int32)>>('getParent').asFunction();
      _createDir = nativeLib.lookup<NativeFunction<Pointer<_DirInfo>? Function(Pointer<f.Utf8>, Bool)>>('createDir').asFunction();
      _createFile = nativeLib.lookup<NativeFunction<Pointer<_DirInfo>? Function(Pointer<f.Utf8>, Bool)>>('createFile').asFunction();
      checkDescriptor = nativeLib.lookup<NativeFunction<Int32 Function(Int32)>>('checkDescriptor').asFunction();
      deleteDir = nativeLib.lookup<NativeFunction<Int32 Function(Int32, Bool)>>('deleteDir').asFunction();
      getFileSize = nativeLib.lookup<NativeFunction<Int32 Function(Int32)>>('getFileSize').asFunction();
      _renameDir = nativeLib.lookup<NativeFunction<Pointer<_DirInfo>? Function(Int32, Pointer<f.Utf8>)>>('renameDir').asFunction();
      _renameFile = nativeLib.lookup<NativeFunction<Pointer<_DirInfo>? Function(Int32, Pointer<f.Utf8>, Bool)>>('renameFile').asFunction();
      deleteFile = nativeLib.lookup<NativeFunction<Int32 Function(Int32)>>('deleteFile').asFunction();
      _fileReadAllBytes = nativeLib.lookup<NativeFunction<Pointer<_FileContent> Function(Int32)>>('fileReadAllBytes').asFunction();
      _fileWriteAllBytes = nativeLib.lookup<NativeFunction<Int32 Function(Int32, Pointer<Uint8>, Int32, Int32)>>('fileWriteAllBytes').asFunction();
      
      _openFile = nativeLib.lookup<NativeFunction<Int32 Function(Int32, Int32)>>('_fopen').asFunction();
      closeFile = nativeLib.lookup<NativeFunction<Int32 Function(Int32)>>('_fclose').asFunction();
      flushFile = nativeLib.lookup<NativeFunction<Int32 Function(Int32)>>('_fflush').asFunction();
      fileSize = nativeLib.lookup<NativeFunction<Int32 Function(Int32)>>('_fsize').asFunction();
      ftell = nativeLib.lookup<NativeFunction<Int32 Function(Int32)>>('_ftell').asFunction();
      readByte = nativeLib.lookup<NativeFunction<Int32 Function(Int32)>>('_freadByte').asFunction();
      readBytes = nativeLib.lookup<NativeFunction<Int32 Function(Int32, Pointer<Uint8>, Int32)>>('_fread').asFunction();
      writeByte = nativeLib.lookup<NativeFunction<Int32 Function(Int32, Int32)>>('_fwriteByte').asFunction();
      writeBytes = nativeLib.lookup<NativeFunction<Int32 Function(Int32, Pointer<Uint8>, Int32)>>('_fwrite').asFunction();
      fseek = nativeLib.lookup<NativeFunction<Int32 Function(Int32, Int32)>>('_fseek').asFunction();
    }
  }

  //Should always check descriptor before performing any operations that requires it
  List<List<String>> listDir(int descriptor) {
    var result = _listDir(descriptor);
    var ret = <List<String>>[];
    if(result != null) {
      List<String> folders = [];
      for(var i = 0; i < result.ref.folderCount; i++) {
        var p = result.ref.folders + i;
        folders.add(p.value.toDartString());
        _allocator.free(p.value);
      }
      List<String> files = [];
      for(var i = 0; i < result.ref.fileCount; i++) {
        var p = result.ref.files + i;
        files.add(p.value.toDartString());
        _allocator.free(p.value);
      }
      ret.add(folders);
      ret.add(files);
      _allocator.free(result);
    }
    return ret;
  }

  List<dynamic> openDir(String path) {
    Pointer<f.Utf8> pathStr = path.toNativeUtf8();
    var result = _openDir(pathStr);
    var ret = <dynamic>[];
    if(result != null) {
      ret.add(result.ref.path.toDartString());
      _allocator.free(result.ref.path);
      ret.add(result.ref.descriptor);
      _allocator.free(result);
    }
    f.malloc.free(pathStr);
    return ret;
  }

  List<dynamic>? createDir(String path, bool r) {
    Pointer<f.Utf8> pathStr = path.toNativeUtf8();
    var result = _createDir(pathStr, r);
    List<dynamic>? ret;
    if(result!.ref.descriptor != 0 && result.ref.descriptor != -1) {
      ret = <dynamic>[];
      ret.add(result.ref.path.toDartString());
      ret.add(result.ref.descriptor);
    }
    _allocator.free(result.ref.path);
    _allocator.free(result);
    f.malloc.free(pathStr);
    return ret;
  }

  List<dynamic>? createFile(String path, bool r) {
    Pointer<f.Utf8> pathStr = path.toNativeUtf8();
    var result = _createFile(pathStr, r);
    List<dynamic>? ret;
    if(result!.ref.descriptor != 0 && result.ref.descriptor != -1) {
      ret = <dynamic>[];
      ret.add(result.ref.path.toDartString());
      ret.add(result.ref.descriptor);
    }
    _allocator.free(result.ref.path);
    _allocator.free(result);
    f.malloc.free(pathStr);
    return ret;
  }

  List<dynamic>? renameDir(int descriptor, String newName) {
    Pointer<f.Utf8> pathStr = newName.toNativeUtf8();
    var result = _renameDir(descriptor, pathStr);
    List<dynamic>? ret;
    if(result!.ref.descriptor != 0 && result.ref.descriptor != -1) {
      ret = <dynamic>[];
      ret.add(result.ref.path.toDartString());
      ret.add(result.ref.descriptor);
    }
    _allocator.free(result.ref.path);
    _allocator.free(result);
    f.malloc.free(pathStr);
    return ret;
  }

  List<dynamic>? renameFile(int descriptor, String newName, bool copy) {
    Pointer<f.Utf8> pathStr = newName.toNativeUtf8();
    var result = _renameFile(descriptor, pathStr, copy);
    List<dynamic>? ret;
    if(result!.ref.descriptor != 0 && result.ref.descriptor != -1) {
      ret = <dynamic>[];
      ret.add(result.ref.path.toDartString());
      ret.add(result.ref.descriptor);
    }
    _allocator.free(result.ref.path);
    _allocator.free(result);
    f.malloc.free(pathStr);
    return ret;
  }

  int openFile(int descriptor, FileMode mode) {
    var ret = _nativeProxy._openFile(descriptor, fileModeToInt(mode));
    return ret;
  }
  
  Uint8List fileReadAllBytes(int descriptor) {
    var result = _fileReadAllBytes(descriptor);
    if(result.ref.size != -1) {
      var size = result.ref.size;
      var data = result.ref.data;
      _allocator.free(result);
      return data.asTypedList(size, finalizer: _allocator.nativeFree);
    } else {
      _allocator.free(result.ref.data);
      _allocator.free(result);
      return Uint8List(0);
    }
  }

  int fileModeToInt(FileMode m) {
    return switch(m) {
      FileMode.read => 0,
      FileMode.write => 1,
      FileMode.append => 2,
      FileMode.writeOnly => 3,
      FileMode.writeOnlyAppend => 4,
      FileMode() => throw UnimplementedError(),
    };
  }
  
  int fileWriteAllBytes(int descriptor, List<int> bytes, FileMode m) {
    var p = _allocator.allocate<Uint8>(bytes.length);
    var arr = p.asTypedList(bytes.length);
    arr.setAll(0, bytes);
    var ret = _fileWriteAllBytes(descriptor, p, bytes.length, fileModeToInt(m));
    _allocator.free(p);
    return ret;
  }
}

final _nativeProxy = _AndroidNativePathFuncProxy();

class _AndroidNativeAllocator implements Allocator {
  @override
  Pointer<T> allocate<T extends NativeType>(int byteCount, {int? alignment}) {
    return _nativeProxy.malloc(byteCount).cast<T>();
  }

  @override
  void free(Pointer<NativeType> pointer) {
    _nativeProxy.free(pointer.cast<Void>());
  }

  final Pointer<NativeFinalizerFunction> nativeFree = _nativeProxy.nativeFree;
}

final _allocator = _AndroidNativeAllocator();

void isolateWorker(SendPort sp) {
  final p = ReceivePort();
  sp.send(p.sendPort);

  p.listen((mes) async {
    if(mes is List) {
      final task = mes[0] as int;
      final name = mes[1] as Function;
      final args = mes[2] as List<dynamic>;
      final port = mes[3] as SendPort;

      dynamic result;
      try {
        result = await Function.apply(name, args);
      } catch(e) {
        result = null;
      }

      port.send([task, result]);
    }
  });
}

class SAFTaskWorker {
  factory SAFTaskWorker() =>
      instance ?? (instance = SAFTaskWorker._());

  SAFTaskWorker._();

  static SAFTaskWorker? instance;

  late Isolate _isolate;
  late SendPort _sendPort;
  final _responsePort = ReceivePort();
  final _completerMap = <int, Completer>{};

  Future<void> init() async {
    final readyPort = ReceivePort();
    _isolate = await Isolate.spawn(isolateWorker, readyPort.sendPort);

    _sendPort = await readyPort.first as SendPort;

    _responsePort.listen((message) {
      if (message is List) {
        final taskId = message[0] as int;
        final result = message[1];
        final completer = _completerMap.remove(taskId);
        if (completer != null) {
          completer.complete(result);
        }
      }
    });
  }

  Future<T> runTask<T>(Function func, List<dynamic> args) {
    final completer = Completer<T>();
    _completerMap[completer.hashCode] = completer;

    _sendPort.send([completer.hashCode, func, args, _responsePort.sendPort]);
    return completer.future;
  }

  void dispose() {
    _responsePort.close();
    _isolate.kill(priority: Isolate.immediate);
  }
}

// String _generateRandomString(int length) {
//   final rand = Random();
//   const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz0123456789';
//   return Iterable.generate(
//     length, (_) => chars[rand.nextInt(chars.length)],
//   ).toList().join();
// }

class _Document {
  String _myPath;//resolved path
  int _descriptor;//hashcode of document file, always >=-1

  _Document(this._myPath, this._descriptor);

  ///Validation process must be performed in dart because
  ///only dart holds the path string.
  ///
  ///Calling this function will let kotlin layer to cache the
  ///DocumentFile object if it's a valid path.
  ///
  ///When the cache is full, the eldest DocumentFile will be erased,
  ///causing the descriptor to be invalid, which needs to validate again.
  Future<void> validateDescriptor() async {
    if(_descriptor <= 0) {
      return;
    }
    return FlutterSafPlatform.instance.validate(_descriptor).then((desc) {
      if(desc == -2) {
        //cache miss
        _refreshDoc(_myPath).then((newDesc) {
          if(newDesc == null) {
            _descriptor = -1;
            return;
          }
          _myPath = newDesc._myPath;
          _descriptor = newDesc._descriptor;
        });
      }
    });
  }

  void validateDescriptorSync() {
    if(_descriptor <= 0) {
      return;
    }
    var desc = _nativeProxy.checkDescriptor(_descriptor);

    if(desc == -2) {
      //cache miss
      var newDesc = _refreshDocSync(_myPath)!;
      _myPath = newDesc._myPath;
      _descriptor = newDesc._descriptor;
    }
  }

  static Future<_Document?> _refreshDoc(String path){
    return FlutterSafPlatform.instance.open(path).then((result) {
      if(result == null || result.length != 2) {
        return null;
      }
      if(result[1] == -3) {
        return null;
      }
      return _Document(result[0], result[1]);
    });
  }

  static _Document? _refreshDocSync(String path){
    var result = _nativeProxy.openDir(path);
    if(result.length != 2) {
      return null;
    }
    if(result[1] == -3) {
      return null;
    }
    return _Document(result[0], result[1]);
  }
}

class AndroidDirectory extends _Document implements Directory {

  AndroidDirectory._(super._myPath, super._descriptor);

  static Future<AndroidDirectory?> pickDirectory() async {
    return FlutterSafPlatform.instance.pick().then((result) {
      if(result != null) {
        return AndroidDirectory._(
            result[0],
            int.parse(result[1])
        );
      }
      return null;
    });
  }

  static AndroidDirectory? fromPathSync(String path) {
    var doc = _Document._refreshDocSync(path);
    if(doc == null) {
      return null;
    }
    return AndroidDirectory._(doc._myPath, doc._descriptor);
  }

  static Future<AndroidDirectory?> fromPath(String path) async {
    return _Document._refreshDoc(path).then((result) {
      if(result == null) {
        return null;
      }
      return AndroidDirectory._(result._myPath, result._descriptor);
    });
  }

  @override
  Directory get absolute => this;

  @override
  Future<Directory> create({bool recursive = false}) async {
    if(_descriptor == 0) {
      throw FileSystemException("Cannot create directory specified.", _myPath);
    }
    return FlutterSafPlatform.instance.create(_myPath, recursive).then((result) {
      if(result == null) {
        throw FileSystemException("Cannot create directory specified.", _myPath);
      }
      _myPath = result[0];
      _descriptor = result[1];
      return this;
    });
  }

  @override
  void createSync({bool recursive = false}) {
    if(_descriptor == 0) {
      return;
    }
    var result = _nativeProxy.createDir(_myPath, recursive);
    if(result == null) {
      throw FileSystemException("Cannot create directory specified.", _myPath);
    }
    _myPath = result[0];
    _descriptor = result[1];
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    return validateDescriptor().then((_){
      return FlutterSafPlatform.instance.delete(_descriptor, recursive).then((result) {
        switch(result) {
          case 0 : _descriptor = -1;
          case -1: throw FileSystemException("Directory path is invalid", _myPath);
          case -3: throw FileSystemException("Directory is not empty", _myPath);
          //unbelievable
          case -2: throw FileSystemException("Directory descriptor is invalid", _myPath);
        }
        return this;
      });
    });
  }

  @override
  void deleteSync({bool recursive = false}) {
    validateDescriptorSync();
    var result = _nativeProxy.deleteDir(_descriptor, recursive);
    switch(result) {
      case 0 : _descriptor = -1;
      case -1: throw FileSystemException("Directory path is invalid", _myPath);
      case -3: throw FileSystemException("Directory is not empty", _myPath);
      //unbelievable
      case -2: throw FileSystemException("Directory descriptor is invalid", _myPath);
    }
  }

  @override
  Future<bool> exists() async {
    if(_descriptor < 0) {
      return Future.value(false);
    }
    return validateDescriptor().then((v) {
      return _descriptor >= 0;
    });
  }

  @override
  bool existsSync() {
    if(_descriptor < 0) {
      return false;
    }
    validateDescriptorSync();
    return _descriptor >= 0;
  }

  @override
  bool get isAbsolute => true;

  @override
  Stream<FileSystemEntity> list({bool recursive = false, bool followLinks = true}) async* {
    if(_descriptor < 0) {
      return;
    }
    validateDescriptorSync();

    var dirContent = await SAFTaskWorker().runTask(_nativeProxy.listDir, [_descriptor]);
    if(dirContent == null) {
      return;
    }
    for(var d in dirContent[0]) {
      var df = await fromPath("$_myPath/$d");
      yield df!;
      if(recursive) {
        yield* df.list(recursive: recursive, followLinks: followLinks);
      }
    }
    for(var d in dirContent[1]) {
      yield (await AndroidFile.fromPath("$_myPath/$d"))!;
    }
  }

  @override
  List<FileSystemEntity> listSync({bool recursive = false, bool followLinks = true}) {
    var result = <FileSystemEntity>[];
    if(_descriptor < 0) {
      return result;
    }
    validateDescriptorSync();
    var dirContent = _nativeProxy.listDir(_descriptor);
    for(var dir in dirContent[0]) {
      var d = fromPathSync("$_myPath/$dir")!;
      result.add(d);
      if(recursive) {
        result.addAll(d.listSync(recursive: recursive, followLinks: followLinks));
      }
    }

    for(var file in dirContent[1]) {
      result.add(AndroidFile.fromPathSync("$_myPath/$file")!);
    }
    return result;
  }

  @override
  Directory get parent {
    if(_descriptor < 0) {
      throw const FileSystemException("Invalid directory.");
    }
    validateDescriptor();
    var r = _nativeProxy.getParent(_descriptor);
    if(r != -1) {
      //Already opened, thus we construct directly
      return AndroidDirectory._(_myPath.substring(0, _myPath.lastIndexOf('/')), r);
    }
    throw const FileSystemException("Invalid directory.");
  }

  @override
  String get path => _myPath;

  @override
  Future<Directory> rename(String newPath) async {
    if(_descriptor == -1) {
      throw FileSystemException("Cannot rename because the directory doesn't exist.", _myPath);
    }
    if(_descriptor == 0) {
      throw FileSystemException("Cannot rename because the directory is a root directory.", _myPath);
    }
    return validateDescriptor().then((v) {
      return FlutterSafPlatform.instance.rename(_descriptor, newPath).then((result) {
        if(result == null) {
          throw FileSystemException("Rename failed", _myPath);
        }
        _myPath = result[0];
        _descriptor = result[1];
        if(_descriptor == -3) {
          return Directory(_myPath);
        }
        return this;
      });
    });
  }

  @override
  Directory renameSync(String newPath) {
    if(_descriptor == -1) {
      throw FileSystemException("Cannot rename because the directory doesn't exist.", _myPath);
    }
    if(_descriptor == 0) {
      throw FileSystemException("Cannot rename because the directory is a root directory.", _myPath);
    }
    validateDescriptorSync();
    var result = _nativeProxy.renameDir(_descriptor, newPath);
    if(result == null) {
      throw FileSystemException("Rename failed", _myPath);
    }
    _myPath = result[0];
    _descriptor = result[1];
    if(_descriptor == -3) {
      return Directory(_myPath);
    }
    return this;
  }

  // TODO: region not implemented
  @override
  Future<Directory> createTemp([String? prefix]) {
    throw UnimplementedError();
  }

  @override
  Directory createTempSync([String? prefix]) {
    throw UnimplementedError();
  }

  @override
  Future<String> resolveSymbolicLinks() {
    throw UnimplementedError();
  }

  @override
  String resolveSymbolicLinksSync() {
    throw UnimplementedError();
  }

  @override
  Future<FileStat> stat() {
    throw UnimplementedError();
  }

  @override
  FileStat statSync() {
    throw UnimplementedError();
  }

  @override
  Uri get uri => throw UnimplementedError();

  @override
  Stream<FileSystemEvent> watch({int events = FileSystemEvent.all, bool recursive = false}) {
    throw UnimplementedError();
  }
}

class AndroidFile extends _Document implements File {

  AndroidFile._(super._myPath, super._descriptor);

  static AndroidFile? fromPathSync(String path) {
    var doc = _Document._refreshDocSync(path);
    if(doc == null) {
      return null;
    }
    return AndroidFile._(doc._myPath, doc._descriptor);
  }

  static Future<AndroidFile?> fromPath(String path) async {
    return _Document._refreshDoc(path).then((result) {
      if(result == null) {
        return null;
      }
      return AndroidFile._(result._myPath, result._descriptor);
    });
  }

  @override
  File get absolute => this;

  @override
  Future<File> copy(String newPath) {
    if(_descriptor == -1) {
      throw FileSystemException("Cannot rename because the file doesn't exist.", _myPath);
    }
    if(_descriptor == 0) {
      throw FileSystemException("Cannot rename because the file is a root directory.", _myPath);
    }
    return validateDescriptor().then((v) {
      return SAFTaskWorker().runTask(_nativeProxy._renameFile, [_descriptor, newPath, true]).then((result) {
        if(result == null) {
          throw FileSystemException("Rename failed", _myPath);
        }
        _myPath = result[0];
        _descriptor = result[1];
        return this;
      });
    });
  }

  @override
  File copySync(String newPath) {
    if(_descriptor == -1) {
      throw FileSystemException("Cannot rename because the file doesn't exist.", _myPath);
    }
    if(_descriptor == 0) {
      throw FileSystemException("Cannot rename because the file is a root directory.", _myPath);
    }
    validateDescriptorSync();
    var result = _nativeProxy.renameFile(_descriptor, newPath, true);
    if(result == null) {
      throw FileSystemException("Rename failed", _myPath);
    }
    _myPath = result[0];
    _descriptor = result[1];
    return this;
  }

  @override
  Future<File> create({bool recursive = false, bool exclusive = false}) {
    if(_descriptor == 0) {
      throw FileSystemException("Cannot create directory specified.", _myPath);
    }
    return SAFTaskWorker().runTask<List<dynamic>?>(
        _nativeProxy.createFile, [_myPath, recursive]).then((result) {
      if(result == null) {
        throw FileSystemException("Cannot create directory specified.", _myPath);
      }
      _myPath = result[0];
      _descriptor = result[1];
      return this;
    });
  }

  @override
  void createSync({bool recursive = false, bool exclusive = false}) {
    if(_descriptor == 0) {
      return;
    }
    var result = _nativeProxy.createFile(_myPath, recursive);
    if(result == null) {
      throw FileSystemException("Cannot create directory specified.", _myPath);
    }
    _myPath = result[0];
    _descriptor = result[1];
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    return validateDescriptor().then((_){
      return SAFTaskWorker().runTask<int>(_nativeProxy.deleteFile, [_descriptor]).then((result) {
        switch(result) {
          case 0 : _descriptor = -1;
          case -1: throw FileSystemException("Directory path is invalid", _myPath);
          case -3: throw FileSystemException("Directory is not empty", _myPath);
          //unbelievable
          case -2: throw FileSystemException("Directory descriptor is invalid", _myPath);
        }
        return this;
      });
    });
  }

  @override
  void deleteSync({bool recursive = false}) {
    validateDescriptorSync();
    var result = _nativeProxy.deleteFile(_descriptor);
    switch(result) {
      case 0 : _descriptor = -1;
      case -1: throw FileSystemException("Directory path is invalid", _myPath);
      case -3: throw FileSystemException("Directory is not empty", _myPath);
      //unbelievable
      case -2: throw FileSystemException("Directory descriptor is invalid", _myPath);
    }
  }

  @override
  Future<bool> exists() async {
    if(_descriptor < 0) {
      return Future.value(false);
    }
    return validateDescriptor().then((v) {
      return _descriptor >= 0;
    });
  }

  @override
  bool existsSync() {
    if(_descriptor < 0) {
      return false;
    }
    validateDescriptorSync();
    return _descriptor >= 0;
  }

  @override
  bool get isAbsolute => true;

  @override
  Future<int> length() {
    return validateDescriptor().then((_){
      return FlutterSafPlatform.instance.fsize(_descriptor).then((s) {
        if(s == null) {
          return 0;
        }
        return s;
      });
    });
  }

  @override
  int lengthSync() {
    validateDescriptorSync();
    return _nativeProxy.getFileSize(_descriptor);
  }

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) {
    return AndroidRandomAccessFile.open(_descriptor, _myPath, mode).then((f) {
      if(f == null) {
        throw FileSystemException("Cannot open file.", _myPath);
      }
      return f;
    });
  }

  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) {
    var f = AndroidRandomAccessFile.openSync(_descriptor, _myPath, mode);
    if(f == null) {
      throw FileSystemException("Cannot open file.", _myPath);
    }
    return f;
  }

  @override
  Directory get parent {
    if(_descriptor < 0) {
      throw FileSystemException("Invalid file.", super._myPath);
    }
    validateDescriptor();
    var r = _nativeProxy.getParent(_descriptor);
    if(r != -1) {
      //Already opened, thus we construct directly
      return AndroidDirectory._(_myPath.substring(0, _myPath.lastIndexOf('/')), r);
    }
    throw FileSystemException("Invalid file.", super._myPath);
  }

  @override
  String get path => super._myPath;

  @override
  Future<Uint8List> readAsBytes() {
    return SAFTaskWorker().runTask<Uint8List>(_nativeProxy.fileReadAllBytes, [_descriptor]);
  }

  @override
  Uint8List readAsBytesSync() {
    return _nativeProxy.fileReadAllBytes(_descriptor);
  }

  @override
  Future<File> rename(String newPath) {
    if(_descriptor == -1) {
      throw FileSystemException("Cannot rename because the file doesn't exist.", _myPath);
    }
    if(_descriptor == 0) {
      throw FileSystemException("Cannot rename because the file is a root directory.", _myPath);
    }
    return validateDescriptor().then((v) {
      return SAFTaskWorker().runTask(_nativeProxy._renameFile, [_descriptor, newPath, false]).then((result) {
        if(result == null) {
          throw FileSystemException("Rename failed", _myPath);
        }
        _myPath = result[0];
        _descriptor = result[1];
        if(_descriptor == -3) {
          return File(_myPath);
        }
        return this;
      });
    });
  }

  @override
  File renameSync(String newPath) {
    if(_descriptor == -1) {
      throw FileSystemException("Cannot rename because the file doesn't exist.", _myPath);
    }
    if(_descriptor == 0) {
      throw FileSystemException("Cannot rename because the file is a root directory.", _myPath);
    }
    validateDescriptorSync();
    var result = _nativeProxy.renameFile(_descriptor, newPath, false);
    if(result == null) {
      throw FileSystemException("Rename failed", _myPath);
    }
    _myPath = result[0];
    _descriptor = result[1];
    if(_descriptor == -3) {
      return File(_myPath);
    }
    return this;
  }

  @override
  Future<File> writeAsBytes(List<int> bytes, {FileMode mode = FileMode.write, bool flush = false}) {
    if(_descriptor == -1) {
      return create(recursive: true).then((_) {
        return SAFTaskWorker().runTask<File>(_nativeProxy._fileWriteAllBytes, [_descriptor, bytes, mode]).then((_) {
          return this;
        });
      });
    } else {
      return SAFTaskWorker().runTask(_nativeProxy._fileWriteAllBytes, [_descriptor, bytes, mode]).then((_) {
        return this;
      });
    }
  }

  @override
  void writeAsBytesSync(List<int> bytes, {FileMode mode = FileMode.write, bool flush = false}) {
    if(_descriptor == -1) {
      createSync(recursive: true);
    }
    //Flush is always true
    _nativeProxy.fileWriteAllBytes(_descriptor, bytes, mode);
  }

  // TODO: region not implement
  @override
  Stream<List<int>> openRead([int? start, int? end]) {
    throw UnimplementedError();
  }

  @override
  IOSink openWrite({FileMode mode = FileMode.write, Encoding encoding = utf8}) {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> readAsLines({Encoding encoding = utf8}) {
    throw UnimplementedError();
  }

  @override
  List<String> readAsLinesSync({Encoding encoding = utf8}) {
    throw UnimplementedError();
  }

  @override
  Future<String> readAsString({Encoding encoding = utf8}) {
    throw UnimplementedError();
  }

  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    throw UnimplementedError();
  }

  @override
  Future<File> writeAsString(String contents, {FileMode mode = FileMode.write, Encoding encoding = utf8, bool flush = false}) {
    throw UnimplementedError();
  }

  @override
  void writeAsStringSync(String contents, {FileMode mode = FileMode.write, Encoding encoding = utf8, bool flush = false}) {
    throw UnimplementedError();
  }

  @override
  Uri get uri => throw UnimplementedError();

  @override
  Stream<FileSystemEvent> watch({int events = FileSystemEvent.all, bool recursive = false}) {
    throw UnimplementedError();
  }

  @override
  Future<DateTime> lastAccessed() {
    throw UnimplementedError();
  }

  @override
  DateTime lastAccessedSync() {
    throw UnimplementedError();
  }

  @override
  Future<DateTime> lastModified() {
    throw UnimplementedError();
  }

  @override
  DateTime lastModifiedSync() {
    throw UnimplementedError();
  }

  @override
  Future<String> resolveSymbolicLinks() {
    throw UnimplementedError();
  }

  @override
  String resolveSymbolicLinksSync() {
    throw UnimplementedError();
  }

  @override
  Future setLastAccessed(DateTime time) {
    throw UnimplementedError();
  }

  @override
  void setLastAccessedSync(DateTime time) {
    throw UnimplementedError();
  }

  @override
  Future setLastModified(DateTime time) {
    throw UnimplementedError();
  }

  @override
  void setLastModifiedSync(DateTime time) {
    throw UnimplementedError();
  }

  @override
  Future<FileStat> stat() {
    throw UnimplementedError();
  }

  @override
  FileStat statSync() {
    throw UnimplementedError();
  }
}

class AndroidRandomAccessFile implements RandomAccessFile{
  final String _myPath;
  int _fd;//file descriptor
  bool _isOperationPending = false;

  AndroidRandomAccessFile._(this._fd, this._myPath);

  static RandomAccessFile? openSync(
      int descriptor,
      String path,
      FileMode mode)
  {
    var fd = _nativeProxy.openFile(descriptor, mode);
    if(fd <= 0) {
      return null;
    }
    return AndroidRandomAccessFile._(fd, path);
  }

  static Future<RandomAccessFile?> open(
      int descriptor,
      String path,
      FileMode mode)
  async {
    return SAFTaskWorker().runTask<int>(
        _nativeProxy.openFile, [descriptor, mode]).then((fd) {
      if(fd <= 0) {
        return null;
      }
      return AndroidRandomAccessFile._(fd, path);
    });
  }

  int _singleOp(int Function(int d) func) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.", _myPath);
    }
    _isOperationPending = true;
    var v = func(_fd);
    _isOperationPending = false;
    if(v < 0) {
      throw FileSystemException("Failed to close file.", _myPath);
    }
    return v;
  }

  Future<int> _singleOpAsync(int Function(int d) func) async {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.", _myPath);
    }
    _isOperationPending = true;
    return SAFTaskWorker().runTask<int>(func, [_fd]).then((v) {
      _isOperationPending = false;
      if(v < 0) {
        throw FileSystemException("Failed to perform the operation.", _myPath);
      }
      return v;
    });
  }

  @override
  Future<void> close() {
    return _singleOpAsync(_nativeProxy.closeFile).then((v){ _fd = -1; return; });
  }

  @override
  void closeSync() {
    _singleOp(_nativeProxy.closeFile);
    _fd = -1;
  }

  @override
  Future<RandomAccessFile> flush() {
    return _singleOpAsync(_nativeProxy.flushFile).then((v) { return this; });
  }

  @override
  void flushSync() {
    _singleOp(_nativeProxy.flushFile);
  }

  @override
  Future<int> length() {
    return _singleOpAsync(_nativeProxy.fileSize).then((s) { return s; });
  }

  @override
  int lengthSync() {
    return _singleOp(_nativeProxy.fileSize);
  }

  @override
  String get path => _myPath;

  @override
  Future<int> position() {
    return _singleOpAsync(_nativeProxy.ftell).then((p) {return p;});
  }

  @override
  int positionSync() {
    return _singleOp(_nativeProxy.ftell);
  }

  @override
  Future<Uint8List> read(int count) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.", _myPath);
    }
    _isOperationPending = true;

    if(count == 0) {
      return Future.value(<Uint8>[] as FutureOr<Uint8List>?);
    }

    final p = _allocator.allocate<Uint8>(count);
    return SAFTaskWorker().runTask<int>(_nativeProxy.readBytes, [_fd, p, count]).then((v) {
      _isOperationPending = false;
      if(v < 0) {
        _allocator.free(p);
        throw FileSystemException("$_fd: Operation failed.", _myPath);
      }
      return p.asTypedList(v, finalizer: _allocator.nativeFree);
    });
  }

  @override
  Future<int> readByte() {
    return _singleOpAsync(_nativeProxy.readByte).then((p) {return p;});
  }

  @override
  int readByteSync() {
    return _singleOp(_nativeProxy.readByte);
  }

  @override
  Future<int> readInto(List<int> buffer, [int start = 0, int? end]) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.", _myPath);
    }
    _isOperationPending = true;
    final count = end == null ? buffer.length - start : end - start;
    final p = _allocator.allocate<Uint8>(count);
    return SAFTaskWorker().runTask<int>(_nativeProxy.readBytes, [_fd, p, count]).then((ret) {
      if(ret < 0) {
        _allocator.free(p);
        _isOperationPending = false;
        throw FileSystemException("$_fd: Operation failed.", _myPath);
      }

      final tp = p.asTypedList(ret);
      buffer.setAll(start, tp);

      _allocator.free(p);
      _isOperationPending = false;
      return ret;
    });
  }

  @override
  int readIntoSync(List<int> buffer, [int start = 0, int? end]) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.", _myPath);
    }
    _isOperationPending = true;
    final count = end == null ? buffer.length - start : end - start;
    final p = _allocator.allocate<Uint8>(count);
    final ret = _nativeProxy.readBytes(_fd, p, count);
    _isOperationPending = false;
    if(ret < 0) {
      _allocator.free(p);
      throw FileSystemException("$_fd: Operation failed.", _myPath);
    }

    final tp = p.asTypedList(ret);
    buffer.setAll(start, tp);

    _allocator.free(p);
    _isOperationPending = false;
    return ret;
  }

  @override
  Uint8List readSync(int count) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.", _myPath);
    }
    _isOperationPending = true;
    final p = _allocator.allocate<Uint8>(count);
    final ret = _nativeProxy.readBytes(_fd, p, count);
    _isOperationPending = false;
    if(ret < 0) {
      _allocator.free(p);
      throw FileSystemException("$_fd: Operation failed.", _myPath);
    }

    return p.asTypedList(ret, finalizer: _allocator.nativeFree);
  }

  @override
  Future<RandomAccessFile> setPosition(int position) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.", _myPath);
    }
    _isOperationPending = true;
    return SAFTaskWorker().runTask<int>(_nativeProxy.fseek, [_fd, position]).then((v) {
      _isOperationPending = false;
      if(v < 0) {
        throw FileSystemException("Failed to set position.", _myPath);
      }
      return this;
    });
  }

  @override
  void setPositionSync(int position) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.", _myPath);
    }
    _isOperationPending = true;
    var v = _nativeProxy.fseek(_fd, position);
    _isOperationPending = false;
    if(v < 0) {
      throw FileSystemException("Failed to set position.", _myPath);
    }
  }

  @override
  Future<RandomAccessFile> writeByte(int value) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.");
    }
    _isOperationPending = true;
    return SAFTaskWorker().runTask(_nativeProxy.writeByte, [_fd, value]).then((v) {
      _isOperationPending = false;
      if(v != 1) {
        throw FileSystemException("Failed to write byte.", _myPath);
      }
      return this;
    });
  }

  @override
  int writeByteSync(int value) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.");
    }
    _isOperationPending = true;
    var v = _nativeProxy.writeByte(_fd, value);
    _isOperationPending = false;
    if(v != 1) {
      throw FileSystemException("Failed to write byte.", _myPath);
    }
    return v;
  }

  @override
  Future<RandomAccessFile> writeFrom(List<int> buffer, [int start = 0, int? end]) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.");
    }
    _isOperationPending = true;
    var count = end == null ? buffer.length - start : end - start;
    var p = _allocator.allocate<Uint8>(count);
    var a = p.asTypedList(count);
    a.setAll(0, buffer.getRange(start, start + count));
    return SAFTaskWorker().runTask(_nativeProxy.writeBytes, [_fd, p, count]).then((v) {
      _isOperationPending = false;
      _allocator.free(p);
      if(v != count) {
        throw FileSystemException("$_fd: Failed to write bytes.");
      }
      return this;
    });
  }

  @override
  void writeFromSync(List<int> buffer, [int start = 0, int? end]) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.");
    }
    _isOperationPending = true;
    var count = end == null ? buffer.length - start : end - start;
    var p = _allocator.allocate<Uint8>(count);
    var a = p.asTypedList(count);
    a.setAll(0, buffer.getRange(start, start + count));
    var v = _nativeProxy.writeBytes(_fd, p, count);
    _isOperationPending = false;
    _allocator.free(p);
    if(v != count) {
      throw FileSystemException("$_fd: Failed to write bytes.");
    }
  }

  // TODO: region not implement
  @override
  Future<RandomAccessFile> writeString(String string, {Encoding encoding = utf8}) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.");
    }
    throw UnimplementedError();
  }

  @override
  void writeStringSync(String string, {Encoding encoding = utf8}) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.");
    }
  }

  @override
  Future<RandomAccessFile> truncate(int length) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.");
    }
    throw UnimplementedError();
  }

  @override
  void truncateSync(int length) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.");
    }
  }

  @override
  Future<RandomAccessFile> lock([FileLock mode = FileLock.exclusive, int start = 0, int end = -1]) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.");
    }
    throw UnimplementedError();
  }

  @override
  void lockSync([FileLock mode = FileLock.exclusive, int start = 0, int end = -1]) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.");
    }
  }

  @override
  Future<RandomAccessFile> unlock([int start = 0, int end = -1]) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.");
    }
    throw UnimplementedError();
  }

  @override
  void unlockSync([int start = 0, int end = -1]) {
    if(_isOperationPending) {
      throw FileSystemException("$_fd: Operation is pending.");
    }
  }
}