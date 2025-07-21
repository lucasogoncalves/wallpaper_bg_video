// ignore_for_file: avoid_print

// ignore: unnecessary_import
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'preview.dart';

void main() {
  runApp(const WallpaperApp());
}

class WallpaperApp extends StatelessWidget {
  const WallpaperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galeria de Vídeos',
      theme: ThemeData.dark(),
      home: const PermissionScreen(),
    );
  }
}

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  String _status = '';

  Future<void> _requestPermission() async {
    // Para Android 13+
    final videoStatus = await Permission.videos.request();

    // Para Android 12 ou menor
    final storageStatus = await Permission.storage.request();

    print('Permissão de vídeo (Android 13+): $videoStatus');
    print('Permissão de armazenamento (<=12): $storageStatus');

    if (!mounted) return;

    if (videoStatus.isGranted || storageStatus.isGranted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VideoGalleryPage()),
      );
    } else if (videoStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
      setState(() {
        _status = 'Permissão negada permanentemente. Vá até as configurações do app.';
      });
      await openAppSettings();
    } else {
      setState(() {
        _status = 'Permissão negada. Tente novamente.';
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissão necessária')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('O app precisa de permissão para acessar seus vídeos.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _requestPermission,
              child: const Text('Permitir acesso'),
            ),
            const SizedBox(height: 20),
            Text(_status, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class VideoGalleryPage extends StatefulWidget {
  const VideoGalleryPage({super.key});

  @override
  State<VideoGalleryPage> createState() => _VideoGalleryPageState();
}

class _VideoGalleryPageState extends State<VideoGalleryPage> {
  final MethodChannel _channel = const MethodChannel('wallpaper.channel');
  List<AssetEntity> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGallery();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWallpaperHelpDialog(); // Mostra assim que a tela abrir
    });
  }


  void _showWallpaperHelpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Não fecha ao clicar fora
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Atenção'),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          content: const Text(
            'Certifique que este app "Video Wallpaper" está selecionado como plano de fundo.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openLiveWallpaperMenu();
              },
              child: const Text('Abrir Menu de Plano de Fundo'),
            ),
          ],          
        );
      },
    );
  }

  Future<void> _openLiveWallpaperMenu() async {
    const platform = MethodChannel("wallpaper.channel");
    try {
      await platform.invokeMethod("openLiveWallpaperPicker");
    } on PlatformException catch (e) {
      print("Erro ao abrir menu de plano de fundo: $e");
    }
  }


  Future<void> _loadGallery() async {
    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: true,
      );

      final videoList = await albums.first.getAssetListPaged(page: 0, size: 100);
      print('Vídeos encontrados: ${videoList.length}');

      setState(() {
        _videos = videoList;
        _loading = false;
      });
    } catch (e) {
      print('Erro ao carregar galeria: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _openPreview(AssetEntity video) async {
    final file = await video.originFile;
    if (file == null) {
      print('Arquivo não disponível.');
      return;
    }

    Navigator.push(
      // ignore: use_build_context_synchronously
      context,
      MaterialPageRoute(
        builder: (_) => VideoPreviewScreen(
          videoPath: file.path,
          onConfirm: () async {
            await _channel.invokeMethod('setWallpaper', {'videoUri': file.path});
            // ignore: use_build_context_synchronously
            Navigator.pop(context); // fecha a tela de preview
          },
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vídeos da Galeria'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showWallpaperHelpDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? const Center(child: Text('Nenhum vídeo encontrado.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    return FutureBuilder<Uint8List?>(
                      future: video.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                        }
                        return GestureDetector(
                          onTap: () => _openPreview(video),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(snapshot.data!, fit: BoxFit.cover),
                              const Align(
                                alignment: Alignment.bottomCenter,
                                child: Icon(Icons.wallpaper, color: Colors.white, size: 24),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }

}
