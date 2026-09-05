import 'environment_reader_stub.dart'
    if (dart.library.io) 'environment_reader_io.dart'
    as implementation;

String? readProcessEnvironment(String name) =>
    implementation.readProcessEnvironment(name);
