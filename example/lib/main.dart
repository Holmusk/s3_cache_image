import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:s3_cache_image/s3_cache_image.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<bool> clearDiskCachedImages() async {
    final tempDir = await getTemporaryDirectory();
    final cachePath = tempDir.path + '/images';
    final cacheDir = Directory(cachePath);
    try {
      await cacheDir.delete(recursive: true);
    } catch (_) {
      return false;
    }
    return true;
  }

  /// Return the disk cache directory size.
  Future<int> getDiskCachedImagesSize() async {
    final tempDir = await getTemporaryDirectory();
    final cachePath = tempDir.path + '/images';
    final cacheDir = Directory(cachePath);

    print('${cacheDir.path}');
    var size = 0;
    try {
      cacheDir.listSync().forEach((var file) => size += file.statSync().size);
      return size;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width / 2;
    return Scaffold(
      appBar: AppBar(
        title: Text('S3CacheImage'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () async {
              print('delete cache');
              final success = await clearDiskCachedImages();
              if (success) {
                setState(() {});
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () async {
              final size = await getDiskCachedImagesSize();
              print('CACHE SIZE $size');
            },
          )
        ],
      ),
      body: Container(
//        decoration: BoxDecoration(color: Colors.red),
          width: width,
          height: width,
          child: S3CachedImage(
              fit: BoxFit.cover,
              width: width,
              height: width,
              onExpired: (id) {
                final completer = Completer<String>()
                  ..complete('INSERT S3 URL');
                return completer.future;
              },
//        onExpired: null,
              imageURL: 'INSERT S3 URL',
              cacheId: '123-456-789',
              errorWidget: Center(child: Text('ERROR')),
              placeholder: Center(child: Text('Loading')))),
    );
  }
}
