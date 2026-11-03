import 'package:flutter_vlc_player/flutter_vlc_player.dart';

import 'stream_config.dart';

/// Use hardware decode whenever Android/libVLC supports the camera codec.
/// These are conservative tuning presets, NOT guaranteed to eliminate stalls.
VlcPlayerOptions buildVlcOptions(StreamConfig config) {
  final cache = config.profile.cacheMs;
  return VlcPlayerOptions(
    advanced: VlcAdvancedOptions(<String>[
      VlcAdvancedOptions.networkCaching(cache),
      VlcAdvancedOptions.liveCaching(cache),
      VlcAdvancedOptions.clockJitter(cache ~/ 2),
    ]),
    rtp: VlcRtpOptions(<String>[
      VlcRtpOptions.rtpOverRtsp(config.tcp),
    ]),
    video: VlcVideoOptions(<String>[
      VlcVideoOptions.dropLateFrames(true),
    ]),
    extras: <String>[
      '--no-video-title-show',
      '--no-audio',
    ],
  );
}
