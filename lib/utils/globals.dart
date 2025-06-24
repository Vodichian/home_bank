import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1,
    // Number of method calls to be displayed
    errorMethodCount: 5,
    // Number of method calls if stacktrace is provided
    lineLength: 80,
    // Width of the output
    colors: true,
    // Colorful log messages
    printEmojis: true,
    // Print an emoji for each log message
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);