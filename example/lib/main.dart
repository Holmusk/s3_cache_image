import 'dart:async';
import 'package:flutter/material.dart';
import 'package:s3_cache_image/s3_cache_image.dart';

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

  @override
  void initState() {
    setS3CachePath('/s3/cache/images/food/');
    super.initState();
  }

  Future<bool> clearDiskCachedImages() async {
    return clearS3Cache();
  }

  /// Return the disk cache directory size.
  Future<int> getDiskCachedImagesSize() async {
    return getS3CacheSize();
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
                  ..complete('REMOTE URL');
                return completer.future;
              },
              onDebug: (log) {
                print('LOG $log');
              },
              imageURL: 'REMOTE URL',
              cacheId: 'CACHE ID',
              remoteId: 'REMOTE ID',
              errorWidget: Center(child: Text('ERROR')),
              placeholder: Center(child: Text('LOADING')))),
    );
  }
}
