import 'dart:typed_data';
import '../../domain/core/result.dart';
import 'file_export_stub.dart'
    if (dart.library.io) 'file_export_io.dart' as platform_io;

/// Кроссплатформенный сервис сохранения экспортированных артефактов.
final class FileExportService {
  const FileExportService();

  /// Сохраняет бинарный буфер (например, `.schem`) в каталог `exports/`.
  Future<Result<String>> saveBinaryFile({
    required String fileName,
    required Uint8List bytes,
  }) {
    return platform_io.saveBytesToPlatformFile(
      fileName: fileName,
      bytes: bytes,
    );
  }

  /// Сохраняет текстовый скрипт (`.mcfunction`) в каталог `exports/`.
  Future<Result<String>> saveTextFile({
    required String fileName,
    required String content,
  }) {
    return platform_io.saveTextToPlatformFile(
      fileName: fileName,
      textContent: content,
    );
  }
}

