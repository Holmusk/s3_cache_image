import 'package:test/test.dart';
import 'package:s3_cache_image/s3_cache_image.dart';

void main() {
  final image = S3CachedImage(
    imageURL: '123',
    cacheId: '123',
  );
  expect(image, isNotNull);
}
