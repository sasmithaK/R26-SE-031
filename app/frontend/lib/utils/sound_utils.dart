import 'package:audioplayers/audioplayers.dart';

class SoundUtils {
  /// Plays a short feedback sound effect overlapping with any existing sounds.
  static void playFeedback(String assetPath) {
    final player = AudioPlayer();
    player.play(AssetSource(assetPath));
    player.onPlayerComplete.listen((_) => player.dispose());
  }
}
