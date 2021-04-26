library s3_cache_image;

import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

typedef Future<String> ExpiredURLCallback(String id);

class S3CacheManager {
  static final S3CacheManager _shared = S3CacheManager._internal();

  factory S3CacheManager() {
    return _shared;
  }

  S3CacheManager._internal();

  final _logger = Logger.detached('S3CacheManager');
  var _path = '/s3/cache/images/';

  set dirPath(String newPath) {
    _logger.warning('PATH CHANGE FROM $_path to $newPath');
    _path = newPath;
    print(_path);
  }

  String get currentPath => _path;

  Future<String> _getPath(String id) async {
    final dir = await getTemporaryDirectory();
    print(currentPath);
    return dir.path + _path + id;
  }

  Future<File> getFile(String url, String id, String remoteId,
      ExpiredURLCallback callback) async {
    final path = await _getPath(id);
    _logger.finest('Start fetching file at  path $path');
    final file = File(path);
    if (file.existsSync()) {
      _logger.fine('File exist at path $path');
      return file;
    }

    var _downloadUrl = url;
    if (_isExpired(url)) {
      _logger.fine('Url expired, refresh with expired callback');
      if (callback == null) {
        _logger.warning('No refetch callback provided, return null');
        return null;
      }
      _downloadUrl = await callback(remoteId);
    }
    if (_downloadUrl == null) {
      _logger.warning('No response from expired callback, return null');
      return null;
    }

    _logger.fine('Valid Url, commencing download for $_downloadUrl');
    return await _downloadFile(_downloadUrl, id);
  }

  Future<File> _downloadFile(String url, String id) async {
    http.Response response;
    try {
      response = await http.get(Uri(path: url));
    } catch (e) {
      _logger.severe('Failed to download image with error ${e.toString()}', e,
          StackTrace.current);
      return null;
    }

    if (response != null) {
      if (response.statusCode == 200) {
        final path = await _getPath(id);
        final folder = File(path).parent;
        if (!(await folder.exists())) {
          folder.createSync(recursive: true);
        }
        final file = await File(path).writeAsBytes(response.bodyBytes);
        _logger.fine('Download success and file saved to path $path');
        return file;
      } else {
        _logger
            .warning('Download failed with status code ${response.statusCode}');
        return null;
      }
    } else {
      _logger.warning('No response from server');
      return null;
    }
  }

  bool _isExpired(String url) {
    final uri = Uri.dataFromString(url);
    final queries = uri.queryParameters;
    final expiry = int.parse(queries['Expires']);
    if (expiry != null) {
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiry * 1000);
      return DateTime.now().isAfter(expiryDate);
    }
    return true;
  }

  Future<bool> clearCache() async {
    final tempDir = await getTemporaryDirectory();
    final cachePath = tempDir.path + _path;
    final cacheDir = Directory(cachePath);

    try {
      await cacheDir.delete(recursive: true);
    } catch (e) {
      _logger.severe(
          'Failed to delete s3 cache ${e.toString()}', e, StackTrace.current);
      return false;
    }
    return true;
  }

  Future<int> getCacheSize() async {
    final tempDir = await getTemporaryDirectory();
    final cachePath = tempDir.path + _path;
    final cacheDir = Directory(cachePath);

    var size = 0;
    try {
      cacheDir.listSync().forEach((var file) => size += file.statSync().size);
      return size;
    } catch (_) {
      return null;
    }
  }
}
