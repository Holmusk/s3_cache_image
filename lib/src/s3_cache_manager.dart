import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

typedef Future<String> ExpiredURLCallback(String id);

class S3CacheManager {
  static final S3CacheManager _shared = S3CacheManager._internal();

  factory S3CacheManager() {
    return _shared;
  }

  S3CacheManager._internal();

  Future<String> getPath(String id) async {
    final dir = await getTemporaryDirectory();
    return dir.path + '/images/' + id;
  }

  Future<File> getFile(
      String url, String id, ExpiredURLCallback callback) async {
    // CHECK IF FILE EXIST
    // IF FILE EXIST THEN RETURN FILE IMMEDIATELY

    final path = await getPath(id);
    print('$path');
    final file = File(path);
    if (file.existsSync()) {
//      print('>>>>>>>>> FILE EXIST - RETURN');
      return file;
    }

    // PARSE URL AND CHECK IF URL EXPIRED OR NOT
    // IF URL IS EXPIRED CALL EXPIRED CALLBACK TO GET NEW URL
    var _downloadUrl = url;
    if (isExpired(url)) {
//      print('>>>>>>>>> URL IS EXPIRED - REFETCH');
      if (callback == null) {
//        print('>>>>>>>>> NO REFETCH CALLBACK RETURN NULL');
        return null;
      }
      _downloadUrl = await callback(id);
    }
    if (_downloadUrl == null) {
      return null;
    }
//    print('>>>>>>>>> URL NOT EXPIRED DOWNLOAD');
    return await _downloadFile(_downloadUrl, id);
  }

  Future<File> _downloadFile(String url, String id) async {
    http.Response response;
    try {
      response = await http.get(url);
    } catch (e) {
//      print('>>>>>>>>>>>>>>> ERROR DOWNLOAD IMAGE ${e.toString()}');
      return null;
    }

    if (response != null) {
//      print('>>>>>>>>> DOWNLOAD  RESPONSE NOT NULL');
      if (response.statusCode == 200) {
//        print('>>>>>>>>> STATUS CODE 200');
        final path = await getPath(id);
        final folder = File(path).parent;
        if (!(await folder.exists())) {
          folder.createSync(recursive: true);
        }
        final file = await File(path).writeAsBytes(response.bodyBytes);
        return file;
      } else {
//        print('>>>>>>>>> STATUS CODE ${response.statusCode} >>>>>> RETURN NULL');
        return null;
      }
    } else {
//      print('>>>>>>>>> RESPONSE NULL');
      return null;
    }
  }

  bool isExpired(String url) {
    final uri = Uri.dataFromString(url);
    final queries = uri.queryParameters;
    final expiry = int.parse(queries['Expires']);
    if (expiry != null) {
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiry * 1000);
      return DateTime.now().isAfter(expiryDate);
    }
    return true;
  }
}
