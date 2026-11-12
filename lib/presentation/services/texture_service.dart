import 'dart:ui' as ui;
import 'package:flutter/services.dart';

/// Сервис загрузки и кэширования аутентичных текстур Minecraft (Камень, Сундук, Дверь, Рычаг)
/// для аппаратной отрисовки в CustomPainter.
final class TextureService {
  static final TextureService instance = TextureService._();
  TextureService._();

  ui.Image? _stoneImage;
  ui.Image? _chestImage;
  ui.Image? _doorImage;
  ui.Image? _leverImage;
  bool _isLoaded = false;

  ui.Image? get stoneImage => _stoneImage;
  ui.Image? get chestImage => _chestImage;
  ui.Image? get doorImage => _doorImage;
  ui.Image? get leverImage => _leverImage;
  bool get isLoaded => _isLoaded;

  /// Асинхронно предзагружает текстуры из каталога assets/textures/.
  Future<void> loadTextures() async {
    if (_isLoaded) return;
    try {
      _stoneImage = await _loadUiImage('assets/textures/stone.png');
      _chestImage = await _loadUiImage('assets/textures/chest.png');
      _doorImage = await _loadUiImage('assets/textures/door.png');
      _leverImage = await _loadUiImage('assets/textures/lever.png');
      _isLoaded = true;
    } catch (e) {
      // При работе в тестовом окружении без asset-bundle падения не происходит
      _isLoaded = false;
    }
  }

  Future<ui.Image> _loadUiImage(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(byteData.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

