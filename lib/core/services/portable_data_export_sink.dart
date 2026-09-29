export 'portable_data_export_sink_stub.dart'
    if (dart.library.io) 'portable_data_export_sink_io.dart'
    if (dart.library.js_interop) 'portable_data_export_sink_web.dart';
