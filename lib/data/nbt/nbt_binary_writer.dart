import 'dart:convert';
import 'dart:typed_data';

import '../../domain/repositories/i_maze_exporter.dart';
import 'nbt_tag.dart';

/// Высокопроизводительный бинарный сериализатор структуры NBT (Big-Endian).
///
/// Обеспечивает:
/// * Эффективное управление памятью через расширяемый буфер `Uint8List` + `ByteData`
///   с геометрическим ростом ($\times 2$) без промежуточных аллокаций списков;
/// * Запись всех 13 типов тегов спецификации Named Binary Tag в порядке `Endian.big`;
/// * Кодирование вариативных целых чисел `VarInt` (LEB128) для массива `BlockData`
///   спецификации Sponge Schematic v2/v3.
final class NbtBinaryWriter {
  Uint8List _buffer;
  late ByteData _view;
  int _offset = 0;

  NbtBinaryWriter({int initialCapacity = 32768})
      : _buffer = Uint8List(initialCapacity) {
    _view = ByteData.sublistView(_buffer);
  }

  /// Текущее количество записанных байтов.
  int get length => _offset;

  /// Возвращает компактную копию сериализованного NBT-буфера.
  Uint8List toBytes() => Uint8List.sublistView(_buffer, 0, _offset);

  /// Сериализует корневой именованный тег [rootTag] с именем [rootName] (например, `'Schematic'`).
  Uint8List writeRootCompound({
    required String rootName,
    required NbtCompound rootTag,
  }) {
    _offset = 0;
    writeUint8(NbtTagType.tagCompound.id);
    _writeUtf8String(rootName);
    _writeTagPayload(rootTag);
    return Uint8List.fromList(toBytes());
  }

  /// Кодирует последовательность индексов палитры в массив байтов `VarInt` (7 бит данных + 1 бит продолжения).
  static Uint8List encodeVarIntBlockData(
    Uint16List blockIndices, [
    int? count,
  ]) {
    final total = count ?? blockIndices.length;
    final out = Uint8List(total * 3);
    var outOffset = 0;

    for (var i = 0; i < total; i++) {
      var value = blockIndices[i];
      while ((value & ~0x7F) != 0) {
        out[outOffset++] = (value & 0x7F) | 0x80;
        value >>>= 7;
      }
      out[outOffset++] = value & 0x7F;
    }

    return Uint8List.fromList(Uint8List.sublistView(out, 0, outOffset));
  }

  /// Декодирует массив байтов `VarInt` обратно в список целочисленных индексов палитры.
  static List<int> decodeVarIntBlockData(Uint8List bytes) {
    final result = <int>[];
    var i = 0;
    while (i < bytes.length) {
      var value = 0;
      var shift = 0;
      while (true) {
        if (i >= bytes.length) {
          throw const FormatException('Неожиданный конец потока VarInt');
        }
        final b = bytes[i++];
        value |= (b & 0x7F) << shift;
        if ((b & 0x80) == 0) {
          break;
        }
        shift += 7;
        if (shift > 28) {
          throw const FormatException('VarInt превышает допустимую разрядность');
        }
      }
      result.add(value);
    }
    return result;
  }

  void _ensureCapacity(int additionalBytes) {
    final required = _offset + additionalBytes;
    if (required <= _buffer.length) {
      return;
    }
    var newCapacity = _buffer.length * 2;
    while (newCapacity < required) {
      newCapacity *= 2;
    }
    final nextBuffer = Uint8List(newCapacity);
    nextBuffer.setRange(0, _offset, _buffer);
    _buffer = nextBuffer;
    _view = ByteData.sublistView(_buffer);
  }

  void writeUint8(int value) {
    _ensureCapacity(1);
    _view.setUint8(_offset, value & 0xFF);
    _offset += 1;
  }

  void writeInt8(int value) {
    _ensureCapacity(1);
    _view.setInt8(_offset, value);
    _offset += 1;
  }

  void writeInt16(int value) {
    _ensureCapacity(2);
    _view.setInt16(_offset, value, Endian.big);
    _offset += 2;
  }

  void writeUint16(int value) {
    _ensureCapacity(2);
    _view.setUint16(_offset, value, Endian.big);
    _offset += 2;
  }

  void writeInt32(int value) {
    _ensureCapacity(4);
    _view.setInt32(_offset, value, Endian.big);
    _offset += 4;
  }

  void writeInt64(int value) {
    _ensureCapacity(8);
    _view.setInt64(_offset, value, Endian.big);
    _offset += 8;
  }

  void writeFloat32(double value) {
    _ensureCapacity(4);
    _view.setFloat32(_offset, value, Endian.big);
    _offset += 4;
  }

  void writeFloat64(double value) {
    _ensureCapacity(8);
    _view.setFloat64(_offset, value, Endian.big);
    _offset += 8;
  }

  void writeRawBytes(Uint8List bytes) {
    _ensureCapacity(bytes.length);
    _buffer.setRange(_offset, _offset + bytes.length, bytes);
    _offset += bytes.length;
  }

  void _writeUtf8String(String value) {
    final utf8Bytes = utf8.encode(value);
    if (utf8Bytes.length > 65535) {
      throw FormatException(
        'Строка NBT превышает лимит 65535 байт (${utf8Bytes.length})',
      );
    }
    writeUint16(utf8Bytes.length);
    writeRawBytes(Uint8List.fromList(utf8Bytes));
  }

  void _writeTagPayload(NbtTag tag) {
    switch (tag) {
      case NbtEnd():
        break;
      case NbtByte(:final value):
        writeInt8(value);
      case NbtShort(:final value):
        writeInt16(value);
      case NbtInt(:final value):
        writeInt32(value);
      case NbtLong(:final value):
        writeInt64(value);
      case NbtFloat(:final value):
        writeFloat32(value);
      case NbtDouble(:final value):
        writeFloat64(value);
      case NbtByteArray():
        writeInt32(tag.length);
        for (var i = 0; i < tag.length; i++) {
          writeUint8(tag.byteAt(i));
        }
      case NbtString(:final value):
        _writeUtf8String(value);
      case NbtList(:final elementType, :final items):
        writeUint8(items.isEmpty ? NbtTagType.tagEnd.id : elementType.id);
        writeInt32(items.length);
        for (final item in items) {
          _writeTagPayload(item);
        }
      case NbtCompound(:final entries):
        for (final entry in entries.entries) {
          final child = entry.value;
          if (child is NbtEnd) {
            continue;
          }
          writeUint8(child.tagType.id);
          _writeUtf8String(entry.key);
          _writeTagPayload(child);
        }
        writeUint8(NbtTagType.tagEnd.id);
      case NbtIntArray():
        writeInt32(tag.length);
        for (var i = 0; i < tag.length; i++) {
          writeInt32(tag.valueAt(i));
        }
      case NbtLongArray():
        writeInt32(tag.length);
        for (var i = 0; i < tag.length; i++) {
          writeInt64(tag.valueAt(i));
        }
    }
  }
}

/// Десериализатор бинарного потока NBT (Big-Endian) для валидации и инспекции `.schem`.
final class NbtBinaryReader {
  final ByteData _view;
  final Uint8List _bytes;
  int _offset = 0;

  NbtBinaryReader(Uint8List bytes)
      : _bytes = bytes,
        _view = ByteData.sublistView(bytes);

  /// Читает корневой именованный тег `(rootName, NbtCompound)` из потока.
  ({String rootName, NbtCompound rootCompound}) readRootCompound() {
    _offset = 0;
    final rootTypeId = _readUint8();
    if (rootTypeId != NbtTagType.tagCompound.id) {
      throw FormatException(
        'Корневой тег NBT должен быть TAG_Compound (10), получено: $rootTypeId',
      );
    }
    final name = _readUtf8String();
    final compound = _readTagPayload(NbtTagType.tagCompound) as NbtCompound;
    return (rootName: name, rootCompound: compound);
  }

  int _readUint8() => _view.getUint8(_offset++);

  int _readInt8() => _view.getInt8(_offset++);

  int _readInt16() {
    final v = _view.getInt16(_offset, Endian.big);
    _offset += 2;
    return v;
  }

  int _readUint16() {
    final v = _view.getUint16(_offset, Endian.big);
    _offset += 2;
    return v;
  }

  int _readInt32() {
    final v = _view.getInt32(_offset, Endian.big);
    _offset += 4;
    return v;
  }

  int _readInt64() {
    final v = _view.getInt64(_offset, Endian.big);
    _offset += 8;
    return v;
  }

  double _readFloat32() {
    final v = _view.getFloat32(_offset, Endian.big);
    _offset += 4;
    return v;
  }

  double _readFloat64() {
    final v = _view.getFloat64(_offset, Endian.big);
    _offset += 8;
    return v;
  }

  String _readUtf8String() {
    final len = _readUint16();
    final slice = Uint8List.sublistView(_bytes, _offset, _offset + len);
    _offset += len;
    return utf8.decode(slice);
  }

  NbtTag _readTagPayload(NbtTagType type) {
    switch (type) {
      case NbtTagType.tagEnd:
        return const NbtEnd();
      case NbtTagType.tagByte:
        return NbtByte(_readInt8());
      case NbtTagType.tagShort:
        return NbtShort(_readInt16());
      case NbtTagType.tagInt:
        return NbtInt(_readInt32());
      case NbtTagType.tagLong:
        return NbtLong(_readInt64());
      case NbtTagType.tagFloat:
        return NbtFloat(_readFloat32());
      case NbtTagType.tagDouble:
        return NbtDouble(_readFloat64());
      case NbtTagType.tagByteArray:
        final len = _readInt32();
        final arr = Uint8List.sublistView(_bytes, _offset, _offset + len);
        _offset += len;
        return NbtByteArray(arr);
      case NbtTagType.tagString:
        return NbtString(_readUtf8String());
      case NbtTagType.tagList:
        final elemType = NbtTagType.fromId(_readUint8());
        final count = _readInt32();
        final items = <NbtTag>[];
        for (var i = 0; i < count; i++) {
          items.add(_readTagPayload(elemType));
        }
        return NbtList(elementType: elemType, items: items);
      case NbtTagType.tagCompound:
        final map = <String, NbtTag>{};
        while (true) {
          final nextType = NbtTagType.fromId(_readUint8());
          if (nextType == NbtTagType.tagEnd) {
            break;
          }
          final key = _readUtf8String();
          map[key] = _readTagPayload(nextType);
        }
        return NbtCompound(map);
      case NbtTagType.tagIntArray:
        final count = _readInt32();
        final list = List<int>.generate(count, (_) => _readInt32());
        return NbtIntArray(list);
      case NbtTagType.tagLongArray:
        final count = _readInt32();
        final list = List<int>.generate(count, (_) => _readInt64());
        return NbtLongArray(list);
    }
  }
}

/// Кроссплатформенный (Desktop + Web) упаковщик GZip (RFC 1952 + RFC 1951 Deflate + CRC-32).
///
/// Не зависит от `dart:io`, что позволяет генерировать валидные бинарные файлы `.schem`
/// прямо в браузере (Flutter Web) и на всех десктопных платформах.
final class PureDartGzipCompressor implements IBinaryCompressor {
  static final Uint32List _crc32Table = _buildCrc32Table();

  const PureDartGzipCompressor();

  static Uint32List _buildCrc32Table() {
    final table = Uint32List(256);
    for (var i = 0; i < 256; i++) {
      var c = i;
      for (var k = 0; k < 8; k++) {
        if ((c & 1) != 0) {
          c = 0xEDB88320 ^ (c >>> 1);
        } else {
          c = c >>> 1;
        }
      }
      table[i] = c;
    }
    return table;
  }

  /// Вычисляет контрольную сумму CRC-32 (IEEE 802.3) для массива [bytes].
  static int computeCrc32(Uint8List bytes) {
    var crc = 0xFFFFFFFF;
    for (var i = 0; i < bytes.length; i++) {
      final index = (crc ^ bytes[i]) & 0xFF;
      crc = _crc32Table[index] ^ (crc >>> 8);
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  @override
  Uint8List compressGzip(Uint8List rawBytes) {
    // Формируем поток RFC 1951 Deflate с блоками BTYPE=00 (max 65535 байт на блок).
    // Это гарантирует 100% совместимость со всеми парсерами GZip/Zlib (WorldEdit, FAWE, Litematica, dart:io)
    // и мгновенную скорость сериализации без блокировки UI-потока.
    const maxBlockSize = 65535;
    final numBlocks = rawBytes.isEmpty
        ? 1
        : (rawBytes.length + maxBlockSize - 1) ~/ maxBlockSize;

    // 10 байт GZip-заголовок + 5 байт на каждый блок Deflate + данные + 8 байт трейлер (CRC32 + ISIZE).
    final totalLength = 10 + numBlocks * 5 + rawBytes.length + 8;
    final out = Uint8List(totalLength);
    final view = ByteData.sublistView(out);

    // 1. Заголовок GZip (RFC 1952):
    out[0] = 0x1F; // ID1
    out[1] = 0x8B; // ID2
    out[2] = 0x08; // CM = 8 (Deflate)
    out[3] = 0x00; // FLG = 0
    view.setUint32(4, 0, Endian.little); // MTIME = 0
    out[8] = 0x00; // XFL
    out[9] = 0xFF; // OS = Unknown (255)

    var writeOffset = 10;
    var readOffset = 0;

    for (var blockIdx = 0; blockIdx < numBlocks; blockIdx++) {
      final isLast = blockIdx == numBlocks - 1;
      final chunkLen = rawBytes.isEmpty
          ? 0
          : (readOffset + maxBlockSize <= rawBytes.length
              ? maxBlockSize
              : rawBytes.length - readOffset);
      final nlen = (~chunkLen) & 0xFFFF;

      out[writeOffset++] = isLast ? 0x01 : 0x00; // BFINAL=isLast, BTYPE=00
      view.setUint16(writeOffset, chunkLen, Endian.little);
      writeOffset += 2;
      view.setUint16(writeOffset, nlen, Endian.little);
      writeOffset += 2;

      if (chunkLen > 0) {
        out.setRange(
          writeOffset,
          writeOffset + chunkLen,
          rawBytes,
          readOffset,
        );
        writeOffset += chunkLen;
        readOffset += chunkLen;
      }
    }

    // 3. Трейлер GZip: CRC32 и ISIZE в порядке Little-Endian.
    final crc32 = computeCrc32(rawBytes);
    view.setUint32(writeOffset, crc32, Endian.little);
    writeOffset += 4;
    view.setUint32(writeOffset, rawBytes.length & 0xFFFFFFFF, Endian.little);

    return out;
  }
}
