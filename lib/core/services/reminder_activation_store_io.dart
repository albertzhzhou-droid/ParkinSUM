import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'reminder_activation_inbox.dart';

const String reminderActivationInboxFileName =
    'parkinsum_notification_activation_inbox_v1.json';
const int reminderActivationInboxFileMaxBytes = 64 * 1024;

ReminderActivationRecordStore createReminderActivationRecordStore() {
  if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
    return InMemoryReminderActivationRecordStore();
  }
  return FileReminderActivationRecordStore();
}

class FileReminderActivationRecordStore
    implements ReminderActivationRecordStore {
  FileReminderActivationRecordStore({
    Future<Directory> Function()? directoryProvider,
    this.fileName = reminderActivationInboxFileName,
  }) : _directoryProvider = directoryProvider ?? _defaultActivationDirectory;

  final Future<Directory> Function() _directoryProvider;
  final String fileName;
  static final Map<String, Future<void>> _inProcessTails =
      <String, Future<void>>{};

  @override
  Future<T> transaction<T>(
    T Function(List<ReminderNotificationActivation> entries) operation,
  ) async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    final dataFile = File(p.join(directory.path, fileName));
    return _serializeInProcess(
      dataFile.absolute.path,
      () => _lockedTransaction(dataFile, operation),
    );
  }

  Future<T> _lockedTransaction<T>(
    File dataFile,
    T Function(List<ReminderNotificationActivation> entries) operation,
  ) async {
    final lockFile = File('${dataFile.path}.lock');
    final lock = await lockFile.open(mode: FileMode.append);
    await lock.lock(FileLock.exclusive);
    try {
      final List<ReminderNotificationActivation> entries;
      try {
        entries = await _read(dataFile);
      } catch (_) {
        await _quarantine(dataFile);
        rethrow;
      }
      final result = operation(entries);
      await _replace(dataFile, entries);
      return result;
    } finally {
      await lock.unlock();
      await lock.close();
    }
  }

  Future<T> _serializeInProcess<T>(String key, Future<T> Function() operation) {
    final predecessor = _inProcessTails[key] ?? Future<void>.value();
    final barrier = Completer<void>();
    _inProcessTails[key] = barrier.future;
    return () async {
      try {
        await predecessor;
        return await operation();
      } finally {
        barrier.complete();
        if (identical(_inProcessTails[key], barrier.future)) {
          _inProcessTails.remove(key);
        }
      }
    }();
  }

  Future<List<ReminderNotificationActivation>> _read(File file) async {
    if (!await file.exists()) return <ReminderNotificationActivation>[];
    if ((await file.length()) > reminderActivationInboxFileMaxBytes) {
      throw const FormatException('Activation inbox file is oversized.');
    }
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded['schemaVersion'] != reminderActivationInboxSchemaVersion ||
        decoded['entries'] is! List<dynamic>) {
      throw const FormatException('Activation inbox file is invalid.');
    }
    return (decoded['entries'] as List<dynamic>)
        .map(
          (entry) => ReminderNotificationActivation.fromJson(
            Map<String, Object?>.from(entry as Map<dynamic, dynamic>),
          ),
        )
        .toList(growable: true);
  }

  Future<void> _quarantine(File file) async {
    if (!await file.exists()) return;
    final suffix = DateTime.now().toUtc().microsecondsSinceEpoch;
    await file.rename('${file.path}.corrupt.$suffix');
  }

  Future<void> _replace(
    File file,
    List<ReminderNotificationActivation> entries,
  ) async {
    final temporary = File('${file.path}.tmp.${newReminderOpaqueToken()}');
    final encoded = jsonEncode(<String, Object?>{
      'schemaVersion': reminderActivationInboxSchemaVersion,
      'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
    });
    try {
      await temporary.writeAsString(encoded, flush: true);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }
}

Future<Directory> _defaultActivationDirectory() async =>
    Directory(await getDatabasesPath());
