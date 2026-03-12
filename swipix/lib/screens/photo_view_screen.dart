import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoViewScreen extends StatelessWidget {
  final AssetEntity? asset;
  final File? file;

  const PhotoViewScreen({super.key, this.asset, this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SizedBox.expand(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          // Убираем отступы, чтобы картинка не уезжала от краев
          boundaryMargin: EdgeInsets.zero,
          child: Center(
            child: asset != null 
              ? FutureBuilder<Uint8List?>(
                  future: asset!.originBytes,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) return Image.memory(snapshot.data!, fit: BoxFit.contain);
                    return const CircularProgressIndicator(color: Colors.white, strokeWidth: 1);
                  },
                )
              : Image.file(file!, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
