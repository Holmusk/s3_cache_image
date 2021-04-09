library s3_cache_image;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show instantiateImageCodec, Codec;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'src/s3_cache_manager.dart';

/// s3_cache_image for Flutter
/// Copyright (c) 2018 Holmusk
/// Released under MIT License.

void setS3CachePath(String newPath) {
  S3CacheManager().dirPath = newPath;
}

Future<bool> clearS3Cache() {
  return S3CacheManager().clearCache();
}

Future<int> getS3CacheSize() {
  return S3CacheManager().getCacheSize();
}

typedef void DebugCallback(LogRecord log);

class S3CachedImage extends StatefulWidget {
  /// Creates a widget that displays a [placeholder] while an [S3ImageURL] is loading
  /// then cross-fades to display the [S3ImageURL].
  /// The [imageUrl] and [cacheId]  arguments must not be null. Arguments [width],
  /// [height], [fit] are only used for the image and not for the placeholder.

  const S3CachedImage({
    Key key,
    @required this.imageURL,
    @required this.cacheId,
    @required this.remoteId,
    this.showTransition = true,
    this.onExpired,
    this.onDebug,
    this.errorWidget,
    this.placeholder,
    this.width,
    this.height,
    this.fit,
  })  : assert(imageURL != null),
        assert(cacheId != null),
        assert(remoteId != null),
        super(key: key);

  /// The target image URL that is displayed.
  final String imageURL;

  /// The target image Id that is saved to local storage.
  final String cacheId;

  /// The target remote id to refetch data
  final String remoteId;

  /// Callback to refresh expired url
  final ExpiredURLCallback onExpired;

  // Callback exposing log stream for debugging
  final DebugCallback onDebug;

  /// Widget displayed while the target [S3ImageURL] failed loading.
  final Widget errorWidget;

  /// Widget displayed while the target [S3ImageURL] is loading.
  final Widget placeholder;

  /// If non-null, require the image to have this width.
  ///
  /// If null, the image will pick a size that best preserves its intrinsic
  /// aspect ratio. This may result in a sudden change if the size of the
  /// placeholder widget does not match that of the target image. The size is
  /// also affected by the scale factor.
  final double width;

  /// If non-null, require the image to have this height.
  ///
  /// If null, the image will pick a size that best preserves its intrinsic
  /// aspect ratio. This may result in a sudden change if the size of the
  /// placeholder widget does not match that of the target image. The size is
  /// also affected by the scale factor.
  final double height;

  /// How to inscribe the image into the space allocated during layout.
  ///
  /// The default varies based on the other fields. See the discussion at
  /// [paintImage].
  final BoxFit fit;

  ///If false doenst animate between child and placeholder
  final bool showTransition;

  @override
  _S3CachedImageState createState() => _S3CachedImageState();
}

/// The phases a [CachedNetworkImage] goes through.
@visibleForTesting
enum ImagePhase {
  /// Initial state
  start,

  /// Waiting for target image to load
  waiting,

  /// Fading out previous image.
  fadeout,

  /// Fading in new image.
  fadein,

  /// Fade-in complete.
  completed
}

typedef void _ImageProviderResolverListener();

class _ImageProviderResolver {
  _ImageProviderResolver({
    @required this.state,
    @required this.listener,
  }) {
    imageStreamListener = ImageStreamListener(
      _handleImageChanged,
    );
  }

  final _S3CachedImageState state;
  final _ImageProviderResolverListener listener;
  ImageStreamListener imageStreamListener;

  S3CachedImage get widget => state.widget;

  ImageStream _imageStream;
  ImageInfo _imageInfo;

  void resolve(S3CachedNetworkImageProvider provider) {
    final oldImageStream = _imageStream;
    _imageStream = provider.resolve(createLocalImageConfiguration(state.context,
        size: widget.width != null && widget.height != null
            ? new Size(widget.width, widget.height)
            : null));

    if (_imageStream.key != oldImageStream?.key) {
      oldImageStream?.removeListener(imageStreamListener);
      _imageStream.addListener(imageStreamListener);
    }
  }

  void _handleImageChanged(ImageInfo imageInfo, bool synchronousCall) {
    _imageInfo = imageInfo;
    listener();
  }

  void stopListening() {
    _imageStream?.removeListener(imageStreamListener);
  }
}

class _S3CachedImageState extends State<S3CachedImage>
    with TickerProviderStateMixin {
  _ImageProviderResolver _imageResolver;
  S3CachedNetworkImageProvider _imageProvider;

  AnimationController _controller;
  Animation<double> _animation;

  ImagePhase _phase = ImagePhase.start;

  ImagePhase get state => _phase;

  final _logger = Logger('S3CacheImage');

  bool _hasError;

  @override
  void initState() {
    _hasError = false;

    _imageProvider = S3CachedNetworkImageProvider(
        widget.imageURL, widget.cacheId, widget.remoteId, widget.onExpired,
        errorListener: _imageLoadingFailed);

    _imageResolver =
        _ImageProviderResolver(state: this, listener: _updatePhase);

    _controller = AnimationController(value: 1.0, vsync: this)
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((_) {
        _updatePhase();
      });

    if (widget.onDebug != null) {
      print('ONDEBUG != NULL');
      // hierarchicalLoggingEnabled = true;
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((log) {
        print('LOG $log');
      });
    }

    super.initState();
  }

  @override
  void didChangeDependencies() {
    _imageProvider
        .obtainKey(createLocalImageConfiguration(context))
        .then<void>((key) {});

    _resolveImage();
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(S3CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.cacheId != oldWidget.cacheId ||
        widget.placeholder != widget.placeholder) {
      _imageProvider = S3CachedNetworkImageProvider(
          widget.imageURL, widget.cacheId, widget.remoteId, widget.onExpired,
          errorListener: _imageLoadingFailed);
      _resolveImage();
    }
  }

  @override
  void reassemble() {
    _resolveImage();
    super.reassemble();
  }

  void _resolveImage() {
    _logger.finest('Resolve image');
    _imageResolver.resolve(_imageProvider);
    if (_phase == ImagePhase.start) {
      _updatePhase();
    }
  }

  void _updatePhase() {
    _logger.finest('Update phase $_phase');
    setState(() {
      switch (_phase) {
        case ImagePhase.start:
          if (_imageResolver._imageInfo != null || _hasError)
            _phase = ImagePhase.completed;
          else
            _phase = ImagePhase.waiting;
          break;
        case ImagePhase.waiting:
          if (_hasError && widget.errorWidget == null) {
            _phase = ImagePhase.completed;
            return;
          }

          if (_imageResolver._imageInfo != null || _hasError) {
            if (widget.placeholder == null) {
              _startFadeIn();
            } else {
              _startFadeOut();
            }
          }
          break;
        case ImagePhase.fadeout:
          if (_controller.status == AnimationStatus.dismissed) {
            _startFadeIn();
          }
          break;
        case ImagePhase.fadein:
          if (_controller.status == AnimationStatus.completed) {
            // Done finding in new image.
            _phase = ImagePhase.completed;
          }
          break;
        case ImagePhase.completed:
          _hasError = _imageResolver._imageInfo == null;
          // Nothing to do.
          break;
      }
    });
  }

  void _startFadeOut() {
    _logger.finest('Start fade out');
    _controller.duration =
        Duration(milliseconds: widget.showTransition ? 300 : 0);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _phase = ImagePhase.fadeout;
    _controller.reverse(from: 1.0);
  }

  void _startFadeIn() {
    _logger.finest('Start fade in');
    _controller.duration =
        Duration(milliseconds: widget.showTransition ? 700 : 0);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _phase = ImagePhase.fadein;
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _imageResolver.stopListening();
    _controller.dispose();
    super.dispose();
  }

  bool get _isShowingPlaceholder {
    assert(_phase != null);
    switch (_phase) {
      case ImagePhase.start:
      case ImagePhase.waiting:
      case ImagePhase.fadeout:
        return true;
      case ImagePhase.fadein:
      case ImagePhase.completed:
        return _hasError && widget.errorWidget == null;
    }
    return true;
  }

  void _imageLoadingFailed() {
    _logger.warning('Image loading failed');
    _hasError = true;
    _updatePhase();
  }

  @override
  Widget build(BuildContext context) {
    assert(_phase != ImagePhase.start);
    if (_isShowingPlaceholder && widget.placeholder != null) {
      return _fadedWidget(widget.placeholder);
    }

    if (_hasError && widget.errorWidget != null) {
      return _fadedWidget(widget.errorWidget);
    }

    final imageInfo = _imageResolver._imageInfo;

    return RawImage(
      image: imageInfo?.image,
      width: widget.width,
      height: widget.height,
      scale: imageInfo?.scale ?? 1.0,
      color: new Color.fromRGBO(255, 255, 255, _animation?.value ?? 1.0),
      colorBlendMode: BlendMode.modulate,
      fit: widget.fit,
    );
  }

  Widget _fadedWidget(Widget w) {
    return Opacity(opacity: _animation?.value ?? 1.0, child: w);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description
      ..add(new EnumProperty<ImagePhase>('phase', _phase))
      ..add(new DiagnosticsProperty<ImageInfo>(
          'pixels', _imageResolver._imageInfo))
      ..add(new DiagnosticsProperty<ImageStream>(
          'image stream', _imageResolver._imageStream));
  }
}

typedef void ErrorListener();

class S3CachedNetworkImageProvider
    extends ImageProvider<S3CachedNetworkImageProvider> {
  const S3CachedNetworkImageProvider(
      this.url, this.cacheId, this.remoteId, this.callback,
      {this.scale: 1.0, this.errorListener})
      : assert(url != null),
        assert(scale != null);

  /// Web url of the image to load
  final String url;

  final String cacheId;

  final String remoteId;

  final ExpiredURLCallback callback;

  /// Scale of the image
  final double scale;

  /// Listener to be called when images fails to load.
  final ErrorListener errorListener;

  @override
  Future<S3CachedNetworkImageProvider> obtainKey(
      ImageConfiguration configuration) {
    return new SynchronousFuture<S3CachedNetworkImageProvider>(this);
  }

  Future<ui.Codec> _loadAsync(S3CachedNetworkImageProvider key) async {
    if (url.isNotEmpty && cacheId.isNotEmpty && remoteId.isNotEmpty) {
      var cacheManager = S3CacheManager();
      var file = await cacheManager.getFile(url, cacheId, remoteId, callback);
      if (file == null) {
        if (errorListener != null) {
          errorListener();
        }
        return null;
      }
      return await _loadAsyncFromFile(key, file);
    }
  }

  Future<ui.Codec> _loadAsyncFromFile(
      S3CachedNetworkImageProvider key, File file) async {
    assert(key == this);

    final Uint8List bytes = await file.readAsBytes();

    if (bytes.lengthInBytes == 0) {
      if (errorListener != null) {
        errorListener();
      }
      return null;
    }
    return await ui.instantiateImageCodec(bytes);
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    final S3CachedNetworkImageProvider typedOther = other;
    return cacheId == typedOther.cacheId && scale == typedOther.scale;
  }

  @override
  int get hashCode => hashValues(url, cacheId, scale);

  @override
  String toString() => '$runtimeType(id: $cacheId, url: $url scale: $scale)';

  @override
  ImageStreamCompleter load(S3CachedNetworkImageProvider key, decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: key.scale,
//        informationCollector: (StringBuffer information) {
//          information
//            ..writeln('Image provider: $this')
//            ..write('Image key: $key');
//        }
    );
  }
}
