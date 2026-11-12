// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';

// Простой генератор аутентичных 16x16 PNG-текстур Minecraft
void main() {
  final outDir = Directory('assets/textures');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  // 1. Текстура Камня (Minecraft Stone, 16x16)
  final stonePixels = _generateStonePixels();
  File('${outDir.path}/stone.png').writeAsBytesSync(encodePng16x16(stonePixels));

  // 2. Текстура Сундука (Minecraft Chest Front, 16x16)
  final chestPixels = _generateChestPixels();
  File('${outDir.path}/chest.png').writeAsBytesSync(encodePng16x16(chestPixels));

  // 3. Текстура Железной Двери (Minecraft Iron Door, 16x16)
  final doorPixels = _generateDoorPixels();
  File('${outDir.path}/door.png').writeAsBytesSync(encodePng16x16(doorPixels));

  // 4. Текстура Рычага (Minecraft Lever, 16x16)
  final leverPixels = _generateLeverPixels();
  File('${outDir.path}/lever.png').writeAsBytesSync(encodePng16x16(leverPixels));

  print('Текстуры успешно сгенерированы в assets/textures/');
}

List<int> _generateStonePixels() {
  // Аутентичная матрица 16x16 Minecraft stone
  const palette = [
    0xFF686868, 0xFF747474, 0xFF7D7D7D, 0xFF858585, 0xFF919191, 0xFF585858, 0xFF4F4F4F
  ];
  // Базовый рисунок камня со сколами
  final indices = [
    2, 3, 2, 1, 2, 3, 4, 3, 2, 1, 0, 1, 2, 3, 2, 1,
    3, 4, 3, 2, 1, 2, 3, 2, 1, 0, 5, 0, 1, 2, 3, 2,
    2, 3, 2, 1, 0, 1, 2, 1, 0, 5, 6, 5, 0, 1, 2, 3,
    1, 2, 1, 0, 5, 0, 1, 0, 5, 6, 5, 0, 1, 2, 3, 4,
    2, 1, 0, 5, 6, 5, 1, 2, 0, 5, 0, 1, 2, 3, 4, 3,
    3, 2, 1, 0, 5, 0, 2, 3, 1, 0, 1, 2, 3, 4, 3, 2,
    2, 3, 2, 1, 0, 1, 3, 4, 2, 1, 2, 3, 2, 1, 2, 3,
    1, 2, 3, 2, 1, 2, 4, 3, 1, 2, 3, 2, 1, 0, 1, 2,
    0, 1, 2, 3, 2, 3, 3, 2, 0, 1, 2, 1, 0, 5, 0, 1,
    5, 0, 1, 2, 1, 2, 2, 1, 5, 0, 1, 0, 5, 6, 5, 0,
    6, 5, 0, 1, 0, 1, 1, 0, 6, 5, 0, 5, 6, 5, 0, 1,
    5, 0, 1, 2, 1, 0, 0, 5, 5, 0, 1, 0, 5, 0, 1, 2,
    0, 1, 2, 3, 2, 1, 5, 6, 0, 1, 2, 1, 0, 1, 2, 3,
    1, 2, 3, 4, 3, 2, 0, 5, 1, 2, 3, 2, 1, 2, 3, 4,
    2, 3, 4, 3, 2, 1, 1, 0, 2, 3, 4, 3, 2, 3, 4, 3,
    3, 2, 3, 2, 1, 0, 2, 1, 3, 2, 3, 2, 1, 2, 3, 2,
  ];
  return indices.map((i) => palette[i]).toList();
}

List<int> _generateChestPixels() {
  const border = 0xFF2A1C0E;
  const woodDark = 0xFF693E1A;
  const woodMid = 0xFF8B5322;
  const woodLight = 0xFFA6642A;
  const latchBg = 0xFF1E1E1E;
  const latchMetal = 0xFFD8D8D8;
  const latchLight = 0xFFFFFFFF;

  final pixels = List<int>.filled(256, woodMid);

  for (var y = 0; y < 16; y++) {
    for (var x = 0; x < 16; x++) {
      final idx = y * 16 + x;
      // Внешняя темная кайма сундука
      if (x == 0 || x == 15 || y == 0 || y == 15) {
        pixels[idx] = border;
        continue;
      }
      // Разделитель крышки сундука на y=5
      if (y == 5) {
        pixels[idx] = border;
        continue;
      }
      // Внутренние углы и заклепки
      if ((x == 1 || x == 14) && (y == 1 || y == 14 || y == 4 || y == 6)) {
        pixels[idx] = woodDark;
        continue;
      }
      // Узор досок
      if ((x + y) % 3 == 0) {
        pixels[idx] = woodLight;
      } else if ((x * y) % 5 == 0) {
        pixels[idx] = woodDark;
      } else {
        pixels[idx] = woodMid;
      }
      // Железный замок по центру (x=6..9, y=4..8)
      if (x >= 7 && x <= 8 && y >= 4 && y <= 8) {
        if (x == 7 && y == 5) {
          pixels[idx] = latchLight;
        } else if (y == 8) {
          pixels[idx] = latchBg;
        } else {
          pixels[idx] = latchMetal;
        }
      } else if ((x == 6 || x == 9) && y >= 4 && y <= 8) {
        pixels[idx] = latchBg;
      } else if (x >= 7 && x <= 8 && (y == 3 || y == 9)) {
        pixels[idx] = latchBg;
      }
    }
  }
  return pixels;
}

List<int> _generateDoorPixels() {
  const frame = 0xFF5A5A5A;
  const metalLight = 0xFFD8D8D8;
  const metalMid = 0xFFB4B4B4;
  const metalDark = 0xFF8A8A8A;
  const slit = 0xFF1E1E1E;
  const handle = 0xFF2A2A2A;

  final pixels = List<int>.filled(256, metalMid);
  for (var y = 0; y < 16; y++) {
    for (var x = 0; x < 16; x++) {
      final idx = y * 16 + x;
      if (x == 0 || x == 15 || y == 0 || y == 15 || x == 1 || x == 14) {
        pixels[idx] = frame;
      } else if (y == 8) {
        pixels[idx] = frame;
      } else if ((y >= 3 && y <= 5) && ((x >= 4 && x <= 6) || (x >= 9 && x <= 11))) {
        // Окошки в железной двери
        pixels[idx] = slit;
      } else if (y == 9 && x == 12) {
        pixels[idx] = handle;
      } else if ((x + y) % 2 == 0) {
        pixels[idx] = metalLight;
      } else {
        pixels[idx] = metalDark;
      }
    }
  }
  return pixels;
}

List<int> _generateLeverPixels() {
  const transparent = 0x00000000;
  const baseCobble = 0xFF737373;
  const baseDark = 0xFF4A4A4A;
  const stickWood = 0xFF8B5A2B;
  const stickTip = 0xFF4A2A0A;

  final pixels = List<int>.filled(256, transparent);
  for (var y = 0; y < 16; y++) {
    for (var x = 0; x < 16; x++) {
      final idx = y * 16 + x;
      // Основание рычага (булыжник) внизу по центру
      if (y >= 10 && y <= 14 && x >= 4 && x <= 11) {
        pixels[idx] = (x == 4 || x == 11 || y == 14) ? baseDark : baseCobble;
      }
      // Рукоять рычага, наклоненная по диагонали
      if (y == 9 && x == 8) pixels[idx] = stickWood;
      if (y == 8 && x == 9) pixels[idx] = stickWood;
      if (y == 7 && x == 9) pixels[idx] = stickWood;
      if (y == 6 && x == 10) pixels[idx] = stickWood;
      if (y == 5 && x == 11) pixels[idx] = stickWood;
      if (y == 4 && x == 11) pixels[idx] = stickTip;
      if (y == 3 && x == 12) pixels[idx] = stickTip;
    }
  }
  return pixels;
}

Uint8List encodePng16x16(List<int> argbPixels) {
  // Формируем чистый PNG файл с RGBA
  final rawData = Uint8List(16 * 16 * 4 + 16);
  var rawOffset = 0;
  for (var y = 0; y < 16; y++) {
    rawData[rawOffset++] = 0; // Filter type 0 (None)
    for (var x = 0; x < 16; x++) {
      final pixel = argbPixels[y * 16 + x];
      final a = (pixel >> 24) & 0xFF;
      final r = (pixel >> 16) & 0xFF;
      final g = (pixel >> 8) & 0xFF;
      final b = pixel & 0xFF;
      rawData[rawOffset++] = r;
      rawData[rawOffset++] = g;
      rawData[rawOffset++] = b;
      rawData[rawOffset++] = a;
    }
  }

  final compressed = zlib.encode(rawData);

  final builder = BytesBuilder();
  // PNG Magic Header
  builder.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  // IHDR chunk: width=16, height=16, bitDepth=8, colorType=6 (RGBA)
  final ihdrData = ByteData(13)
    ..setUint32(0, 16, Endian.big)
    ..setUint32(4, 16, Endian.big)
    ..setUint8(8, 8)
    ..setUint8(9, 6)
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  _addChunk(builder, 'IHDR', ihdrData.buffer.asUint8List());

  // IDAT chunk
  _addChunk(builder, 'IDAT', Uint8List.fromList(compressed));

  // IEND chunk
  _addChunk(builder, 'IEND', Uint8List(0));

  return builder.toBytes();
}

void _addChunk(BytesBuilder builder, String type, Uint8List data) {
  final length = data.length;
  final lengthBytes = ByteData(4)..setUint32(0, length, Endian.big);
  builder.add(lengthBytes.buffer.asUint8List());

  final typeBytes = type.codeUnits;
  builder.add(typeBytes);
  if (data.isNotEmpty) {
    builder.add(data);
  }

  var crc = 0xFFFFFFFF;
  for (final b in typeBytes) {
    crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >>> 8);
  }
  for (final b in data) {
    crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >>> 8);
  }
  crc = crc ^ 0xFFFFFFFF;

  final crcBytes = ByteData(4)..setUint32(0, crc, Endian.big);
  builder.add(crcBytes.buffer.asUint8List());
}

final List<int> _crcTable = () {
  final table = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      if ((c & 1) != 0) {
        c = 0xEDB88320 ^ (c >>> 1);
      } else {
        c = c >>> 1;
      }
    }
    table[n] = c;
  }
  return table;
}();
