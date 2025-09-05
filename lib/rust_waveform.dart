import 'dart:ffi' as ffi;
import 'dart:io';

// FFI type definitions for the Rust function
typedef GenerateWaveformNative =
    ffi.Void Function(
      ffi.Pointer<ffi.Float>, // samples
      ffi.Int32, // length
      ffi.Int32, // target_points
      ffi.Float, // denoise_threshold
      ffi.Pointer<ffi.Float>, // out_waveform
    );

typedef GenerateWaveform =
    void Function(
      ffi.Pointer<ffi.Float>,
      int,
      int,
      double,
      ffi.Pointer<ffi.Float>,
    );

class RustWaveform {
  late final ffi.DynamicLibrary dylib;

  RustWaveform() {
    if (Platform.isAndroid) {
      dylib = ffi.DynamicLibrary.open('libwaveform.so');
    } else if (Platform.isMacOS) {
      dylib = ffi.DynamicLibrary.open('libwaveform.dylib');
    } else if (Platform.isLinux) {
      dylib = ffi.DynamicLibrary.open('libwaveform.so');
    } else if (Platform.isWindows) {
      dylib = ffi.DynamicLibrary.open('waveform.dll');
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  late final GenerateWaveform generateWaveformWithDenoise = dylib
      .lookupFunction<GenerateWaveformNative, GenerateWaveform>(
        'generate_waveform_with_denoise',
      );
}
