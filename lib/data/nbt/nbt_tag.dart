import 'dart:typed_data';
import 'package:meta/meta.dart';

/// Идентификаторы типов тегов по спецификации Minecraft Named Binary Tag (NBT).
enum NbtTagType {
  tagEnd(0),
  tagByte(1),
  tagShort(2),
  tagInt(3),
  tagLong(4),
  tagFloat(5),
  tagDouble(6),
  tagByteArray(7),
  tagString(8),
  tagList(9),
  tagCompound(10),
  tagIntArray(11),
  tagLongArray(12);

  final int id;
  const NbtTagType(this.id);

  static NbtTagType fromId(int id) {
    for (final value in NbtTagType.values) {
      if (value.id == id) {
        return value;
      }
    }
    throw FormatException('Неизвестный идентификатор NBT-тега: $id');
  }
}

/// Запечатанная иерархия (`sealed class`) тегов спецификации Minecraft NBT.
@immutable
sealed class NbtTag {
  /// Тип тега согласно спецификации NBT.
  NbtTagType get tagType;

  const NbtTag();
}

/// `TAG_End` (0x00) — маркер завершения `TAG_Compound`.
@immutable
final class NbtEnd extends NbtTag {
  const NbtEnd();

  @override
  NbtTagType get tagType => NbtTagType.tagEnd;
}

/// `TAG_Byte` (0x01) — знаковое 8-битное целое число.
@immutable
final class NbtByte extends NbtTag {
  final int value;

  const NbtByte(this.value);

  @override
  NbtTagType get tagType => NbtTagType.tagByte;
}

/// `TAG_Short` (0x02) — знаковое 16-битное целое число (Big-Endian).
@immutable
final class NbtShort extends NbtTag {
  final int value;

  const NbtShort(this.value);

  @override
  NbtTagType get tagType => NbtTagType.tagShort;
}

/// `TAG_Int` (0x03) — знаковое 32-битное целое число (Big-Endian).
@immutable
final class NbtInt extends NbtTag {
  final int value;

  const NbtInt(this.value);

  @override
  NbtTagType get tagType => NbtTagType.tagInt;
}

/// `TAG_Long` (0x04) — знаковое 64-битное целое число (Big-Endian).
@immutable
final class NbtLong extends NbtTag {
  final int value;

  const NbtLong(this.value);

  @override
  NbtTagType get tagType => NbtTagType.tagLong;
}

/// `TAG_Float` (0x05) — 32-битное число с плавающей точкой IEEE 754 (Big-Endian).
@immutable
final class NbtFloat extends NbtTag {
  final double value;

  const NbtFloat(this.value);

  @override
  NbtTagType get tagType => NbtTagType.tagFloat;
}

/// `TAG_Double` (0x06) — 64-битное число с плавающей точкой IEEE 754 (Big-Endian).
@immutable
final class NbtDouble extends NbtTag {
  final double value;

  const NbtDouble(this.value);

  @override
  NbtTagType get tagType => NbtTagType.tagDouble;
}

/// `TAG_Byte_Array` (0x07) — массив байтов с 32-битным префиксом длины.
@immutable
final class NbtByteArray extends NbtTag {
  final Uint8List _bytes;

  NbtByteArray(Uint8List bytes) : _bytes = Uint8List.fromList(bytes);

  /// Защищенная копия массива байтов.
  Uint8List get bytes => Uint8List.fromList(_bytes);

  /// Длина байтового массива.
  int get length => _bytes.length;

  /// Чтение байта по индексу без копирования всего буфера.
  int byteAt(int index) => _bytes[index];

  @override
  NbtTagType get tagType => NbtTagType.tagByteArray;
}

/// `TAG_String` (0x08) — строка в кодировке UTF-8 с 16-битным беззнаковым префиксом длины.
@immutable
final class NbtString extends NbtTag {
  final String value;

  const NbtString(this.value);

  @override
  NbtTagType get tagType => NbtTagType.tagString;
}

/// `TAG_List` (0x09) — однородный список безымянных тегов типа [elementType].
@immutable
final class NbtList extends NbtTag {
  final NbtTagType elementType;
  final List<NbtTag> _items;

  NbtList({
    required this.elementType,
    required List<NbtTag> items,
  }) : _items = List<NbtTag>.unmodifiable(items);

  List<NbtTag> get items => _items;

  @override
  NbtTagType get tagType => NbtTagType.tagList;
}

/// `TAG_Compound` (0x0A) — именованный словарь вложенных тегов, завершаемый `TAG_End`.
@immutable
final class NbtCompound extends NbtTag {
  final Map<String, NbtTag> _entries;

  NbtCompound(Map<String, NbtTag> entries)
      : _entries = Map<String, NbtTag>.unmodifiable(entries);

  Map<String, NbtTag> get entries => _entries;

  NbtTag? operator [](String key) => _entries[key];

  @override
  NbtTagType get tagType => NbtTagType.tagCompound;
}

/// `TAG_Int_Array` (0x0B) — массив 32-битных знаковых целых чисел (Big-Endian).
@immutable
final class NbtIntArray extends NbtTag {
  final Int32List _values;

  NbtIntArray(List<int> values) : _values = Int32List.fromList(values);

  Int32List get values => Int32List.fromList(_values);

  int get length => _values.length;

  int valueAt(int index) => _values[index];

  @override
  NbtTagType get tagType => NbtTagType.tagIntArray;
}

/// `TAG_Long_Array` (0x0C) — массив 64-битных знаковых целых чисел (Big-Endian).
@immutable
final class NbtLongArray extends NbtTag {
  final Int64List _values;

  NbtLongArray(List<int> values) : _values = Int64List.fromList(values);

  Int64List get values => Int64List.fromList(_values);

  int get length => _values.length;

  int valueAt(int index) => _values[index];

  @override
  NbtTagType get tagType => NbtTagType.tagLongArray;
}

