import 'dart:typed_data';
import '../../domain/core/result.dart';

/// Заглушка сохранения файлов для Web-окружения (где прямое обращение к `dart:io` недоступно).
Future<Result<String>> saveBytesToPlatformFile({
  required String fileName,
  required Uint8List bytes,
}) async {
  return Result.success('Экспортировано в буфер памяти браузера: $fileName (${bytes.length} байт)');
}

Future<Result<String>> saveTextToPlatformFile({
  required String fileName,
  required String textContent,
}) async {
  return Result.success('Скрипт подготовлен в памяти браузера: $fileName');
}

