import 'dart:typed_data';

/// 🔊 Converts raw PCM 16-bit mono audio bytes into a valid WAV file byte array
Uint8List pcm16ToWav(Uint8List pcm, {int sampleRate = 16000, int channels = 1}) {
  final b = BytesBuilder();
  void s(String x) => b.add(x.codeUnits);
  void u32(int v) =>
      b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) =>
      b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());

  final byteRate = sampleRate * channels * 2;
  final blockAlign = channels * 2;

  s('RIFF');
  u32(36 + pcm.length);
  s('WAVE');
  s('fmt ');
  u32(16);
  u16(1); // AudioFormat PCM
  u16(channels);
  u32(sampleRate);
  u32(byteRate);
  u16(blockAlign);
  u16(16); // BitsPerSample
  s('data');
  u32(pcm.length);
  b.add(pcm);
  return b.toBytes();
}
