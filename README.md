
# Cached network image
A flutter library to show image from S3 repository and keep them in the cache directory.
This package is based from [https://github.com/renefloor/flutter_cached_network_image].

## How to add

Add this to your package's pubspec.yaml file:
```
dependencies:
  s3_cache_image: "^0.0.1"

```
Add it to your dart file:
```
import 'package:s3_cache_image/s3_cache_image.dart';
```

## How to use

S3ImageCache can be used directly or through the ImageProvider.
```
S3CachedImage(
              fit: BoxFit.cover,
              width: width,
              height: width,
              onExpired: null,
              onDebug: null,
              imageURL: 'INSERT S3 URL HERE',
              cacheId: 'INSERT CACHE ID HERE',
              errorWidget: Center(child: Text('ERROR')),
              placeholder: Center(child: Text('Loading')))
 ```

Files stored in system temporary folder, so it can be cleared automatically by OS if necessary.

Set directory path:
```
setS3CachePath('/s3/cache/newImage/hello/');
```

Get cache size will return future<int>:
```
getS3CacheSize();
```


Purging cache directory will return future<bool>:
```
clearS3Cache();
```




