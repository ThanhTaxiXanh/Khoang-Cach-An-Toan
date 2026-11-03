import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Hybrid composition is deliberately selected for a native SurfaceView.
/// AndroidView's texture/virtual-display path can blank the surface on unlock.
class IjkSurface extends StatelessWidget {
  const IjkSurface({super.key, required this.onCreated});
  final ValueChanged<int> onCreated;

  @override
  Widget build(BuildContext context) {
    const viewType = 'vn.thanhtaxixanh.a500s/ijk_surface';
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (params) {
        return PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: const <String, Object>{},
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..addOnPlatformViewCreatedListener(onCreated)
          ..create();
      },
    );
  }
}
