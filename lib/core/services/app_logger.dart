import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// App-wide logging sink. Every `catch` block that used to swallow its
/// error silently now routes through here instead, and [installGlobalHandlers]
/// wires this in as the destination for anything that isn't caught at all
/// (Flutter framework errors, uncaught async/zone errors). Output goes both
/// to the console (visible via `flutter run` / `adb logcat`) and to a
/// plain-text file on disk, so a log survives after the console scrollback
/// is gone and can be pulled straight off the device with [shareLogFile] —
/// no cable/adb needed to get a repro log out of a tester's phone.
class AppLogger {
  AppLogger._();

  static File? _file;
  static Logger? _logger;

  /// Log file is capped at this size; once exceeded it's truncated on the
  /// next [init] so a long-running install never accumulates an unbounded
  /// file.
  static const _maxBytes = 2 * 1024 * 1024;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory(p.join(dir.path, 'logs'));
    if (!await logDir.exists()) await logDir.create(recursive: true);
    final file = File(p.join(logDir.path, 'app.log'));
    if (await file.exists() && await file.length() > _maxBytes) {
      await file.writeAsString('');
    }
    _file = file;

    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 1,
        errorMethodCount: 8,
        colors: false,
        printEmojis: false,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      output: MultiOutput([ConsoleOutput(), FileOutput(file: file)]),
    );
  }

  static void d(String message) => (_logger?.d(message)) ?? _fallback('D', message);

  static void i(String message) => (_logger?.i(message)) ?? _fallback('I', message);

  static void w(String message, [Object? error, StackTrace? stackTrace]) =>
      (_logger?.w(message, error: error, stackTrace: stackTrace)) ?? _fallback('W', message, error, stackTrace);

  static void e(String message, [Object? error, StackTrace? stackTrace]) =>
      (_logger?.e(message, error: error, stackTrace: stackTrace)) ?? _fallback('E', message, error, stackTrace);

  /// Only hit if something logs before [init] has run.
  static void _fallback(String level, String message, [Object? error, StackTrace? stackTrace]) {
    // ignore: avoid_print
    print('[$level] $message${error != null ? ' — $error' : ''}${stackTrace != null ? '\n$stackTrace' : ''}');
  }

  static File? get logFile => _file;

  /// Opens the OS share sheet with the log file attached — the fastest
  /// path from "something went wrong" on a tester's device to a file that
  /// can actually be inspected.
  static Future<void> shareLogFile() async {
    final file = _file;
    if (file == null || !await file.exists()) return;
    await Share.shareXFiles([XFile(file.path)], text: 'Dr.Cardio app log');
  }
}
