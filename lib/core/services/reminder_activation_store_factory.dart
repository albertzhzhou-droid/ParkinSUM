import 'reminder_activation_inbox.dart';
import 'reminder_activation_store_stub.dart'
    if (dart.library.io) 'reminder_activation_store_io.dart'
    as implementation;

ReminderActivationRecordStore createReminderActivationRecordStore() =>
    implementation.createReminderActivationRecordStore();
