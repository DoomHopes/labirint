import 'dart:io';
import 'dart:typed_data';
import '../../domain/core/result.dart';

/// Реализация сохранения экспортированных файлов `.schem` и `.mcfunction` на диск для Desktop.
Future<Result<String>> saveBytesToPlatformFile({
  required String fileName,
  required Uint8List bytes,
}) async {
  try {
    final exportDir = Directory('${Directory.current.path}${Platform.pathSeparator}exports');
    if (!exportDir.existsSync()) {
      exportDir.createSync(recursive: true);
    }
    final file = File('${exportDir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return Result.success(file.path);
  } catch (e) {
    return Result.failure(
      DomainError(
        code: 'FILE_WRITE_ERROR',
        message: 'Не удалось сохранить бинарный файл на диск.',
        details: e.toString(),
      ),
    );
  }
}

Future<Result<String>> saveTextToPlatformFile({
  required String fileName,
  required String textContent,
}) async {
  try {
    final exportDir = Directory('${Directory.current.path}${Platform.pathSeparator}exports');
    if (!exportDir.existsSync()) {
      exportDir.createSync(recursive: true);
    }
    final file = File('${exportDir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(textContent, flush: true);
    return Result.success(file.path);
  } catch (e) {
    return Result.failure(
      DomainError(
        code: 'FILE_WRITE_ERROR',
        message: 'Не удалось сохранить текстовый скрипт на диск.',
        details: e.toString(),
      ),
    );
  }
}

