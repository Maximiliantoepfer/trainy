import 'package:pigeon/pigeon.dart';

// The JSON documents have a versioned contract shared by both native runtimes.
// Pigeon handles the transport, nullability and platform errors.
@HostApi()
abstract class CardioHostApi {
  @async
  String prepare(bool outdoor, String locale);
  String capabilities();
  void start(String snapshotJson);
  void recover(String runtimeJson);
  void discard();
  String? state();
  String samples(int afterSequence);
  void pause();
  void resume();
  void finish();
  void setAudioEnabled(bool enabled);
  void acknowledge(String sessionId);
  void openSettings();
}
