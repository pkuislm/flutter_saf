import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_saf_platform_interface.dart';


/// An implementation of [FlutterSafPlatform] that uses method channels.
class MethodChannelFlutterSaf extends FlutterSafPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_saf');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<List<String>?> pick() {
    return methodChannel.invokeListMethod<String>("pick");
  }

  @override
  Future<List<dynamic>?> open(String p) {
    return methodChannel.invokeListMethod<dynamic>("open", <String, String>{"p": p});
  }

  @override
  Future<int?> validate(int d) {
    return methodChannel.invokeMethod<int>("validate", <String, int>{"d": d});
  }

  @override
  Future<List<dynamic>?> create(String p, bool r) {
    return methodChannel.invokeListMethod<dynamic>("createDir", <String, dynamic>{"p":p, "r":r});
  }

  @override
  Future<int?> delete(int d, bool r) {
    return methodChannel.invokeMethod<int>("delete", <String, dynamic>{"d":d, "r":r});
  }

  @override
  Future<List<List<String>>?> list(int d) {
    return methodChannel.invokeListMethod<List<String>>("list", <String, int>{"d":d});
  }

  @override
  Future<List<dynamic>?> rename(int d, String n) {
    return methodChannel.invokeListMethod<dynamic>("rename", <String, dynamic>{"d":d, "n":n});
  }

  @override
  Future<int?> fsize(int d) {
    return methodChannel.invokeMethod<int>("fsize", <String, dynamic>{"d":d});
  }

  @override
  Future<void> test(int d, String n) {
    return methodChannel.invokeMethod("rt", <String, dynamic>{"d":d, "n":n});
  }
}
