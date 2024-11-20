import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_saf_method_channel.dart';

abstract class FlutterSafPlatform extends PlatformInterface {
  /// Constructs a FlutterSafPlatform.
  FlutterSafPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterSafPlatform _instance = MethodChannelFlutterSaf();

  /// The default instance of [FlutterSafPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterSaf].
  static FlutterSafPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterSafPlatform] when
  /// they register themselves.
  static set instance(FlutterSafPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<List<String>?> pick() {
    throw UnimplementedError('pick() has not been implemented.');
  }

  Future<List<dynamic>?> open(String p) {
    throw UnimplementedError('open() has not been implemented.');
  }

  Future<int?> validate(int d) {
    throw UnimplementedError('validate() has not been implemented.');
  }

  Future<List<dynamic>?> create(String p, bool r) {
    throw UnimplementedError('create() has not been implemented.');
  }

  Future<int?> delete(int d, bool r) {
    throw UnimplementedError('delete() has not been implemented.');
  }

  Future<List<List<String>>?> list(int d) {
    throw UnimplementedError('list() has not been implemented.');
  }

  Future<List<dynamic>?> rename(int d, String n) {
    throw UnimplementedError('rename() has not been implemented.');
  }

  Future<int?> fsize(int d) {
    throw UnimplementedError('fsize() has not been implemented.');
  }

  Future<void> test(int d, String n) {
    throw UnimplementedError('test() has not been implemented.');
  }
}
