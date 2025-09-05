t # Butterfly 录音应用

一个功能丰富的Flutter录音应用，支持实时波形显示、标记功能和文件管理。

## 主要功能

### 1. 录音功能
- 使用 `record` 插件进行高质量录音
- 支持M4A格式音频输出（AAC编码，44.1kHz采样率）
- 实时波形显示（模拟PCM数据分析）
- 录音时标记功能，可添加时间标记点
- 暂停/恢复录音功能

### 2. 文件管理
- 集成 `flutter_slidable` 支持滑动操作
- 支持文件重命名（同步重命名相关文件）
- 支持文件删除（删除音频文件及相关数据文件）
- 自动刷新文件列表

### 3. 音频播放
- 高质量音频播放器
- 波形可视化显示
- 标记点在波形上的显示（红色竖线）
- 播放控制（播放/暂停、快进/快退）
- 时间轴显示和进度控制

### 4. 数据管理
- 自动保存波形数据（.wave.json）
- 自动保存标记点数据（.marks.json）
- 文件重命名时同步更新相关数据文件
- 文件删除时清理所有相关数据

## 技术特性

### 依赖项
- `record: ^6.0.0` - 录音功能
- `audioplayers: ^5.2.1` - 音频播放
- `flutter_slidable: ^3.0.1` - 滑动操作
- `path_provider: ^2.1.2` - 文件路径管理
- `permission_handler: ^11.0.1` - 权限管理

### 文件结构
```
lib/
├── main.dart              # 主页面（文件列表）
├── record_page.dart       # 录音页面
└── audio_player_page.dart # 音频播放页面
```

### 数据文件
- `audio.m4a` - 音频文件
- `audio.m4a.wave.json` - 波形数据
- `audio.m4a.marks.json` - 标记点数据

## 使用说明

### 录音
1. 点击右下角的麦克风按钮开始录音
2. 录音过程中可以点击标记按钮添加时间标记
3. 可以暂停和恢复录音
4. 点击停止按钮结束录音

### 文件管理
1. 在文件列表中向左滑动显示操作按钮
2. 点击"重命名"可以修改文件名
3. 点击"删除"可以删除文件及相关数据

### 播放
1. 点击文件列表中的任意文件进入播放页面
2. 波形上的红色竖线表示标记点
3. 使用播放控制按钮控制播放
4. 可以拖动进度条或点击波形进行跳转

## 开发说明

### 实时波形分析
当前版本使用模拟数据生成波形，在实际项目中可以通过以下方式实现真正的PCM数据分析：

1. 使用 `record` 插件的 `onData` 回调（需要插件支持）
2. 使用 `just_audio` 插件获取音频数据
3. 使用原生平台通道获取实时音频数据

### 标记功能
标记点数据以毫秒为单位存储，在播放时自动加载并显示在波形上。

### 文件同步
重命名和删除操作会自动处理相关的数据文件，确保数据一致性。

## 未来改进

1. 实现真正的实时PCM波形分析
2. 添加音频编辑功能
3. 支持更多音频格式
4. 添加音频效果和滤镜
5. 实现云端同步功能

## Rust 波形/降噪库编译与集成说明

本项目通过 Rust 实现高性能的音频波形与降噪处理，并通过 FFI 集成到 Flutter。
如需修改或重新编译 Rust 动态库，请参考以下步骤：

### 1. 安装 Rust 工具链

请确保已安装 Rust（推荐使用 [rustup](https://rustup.rs/)）：

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### 2. 安装交叉编译工具（Android）

建议使用 [`cargo-ndk`](https://github.com/bbqsrc/cargo-ndk) 简化 Android so 库编译：

```bash
cargo install cargo-ndk
```

### 3. 编译 Android so 动态库

在 `butterfly/rust` 目录下执行：

```bash
cargo ndk -t arm64-v8a -o ../android/app/src/main/jniLibs build --release
```

- 编译完成后，`libwaveform.so` 会自动拷贝到 `android/app/src/main/jniLibs/arm64-v8a/` 目录。

### 4. 编译 macOS 动态库

```bash
cargo build --release
# 生成的 dylib 路径： target/release/libwaveform.dylib
# 可拷贝到 macos/Runner/ 目录下供 FFI 加载
```

### 5. 编译 iOS 动态库（可选）

iOS 需生成静态库（.a），并通过 Xcode 配置集成，具体可参考 [flutter_rust_bridge 文档](https://cjycode.com/flutter_rust_bridge/manual/integrate/ios.html)。

### 6. Rust FFI 接口说明

Rust 导出函数 `generate_waveform_with_denoise`，Dart 端通过 FFI 调用，接口定义详见 `lib/rust_waveform.dart`。

### 7. 常见问题

- Android 编译需安装 NDK 并配置环境变量（可用 Android Studio 安装）。
- 若遇到找不到 so/dylib，请确认路径与平台架构一致。
- 修改 Rust 代码后需重新编译并覆盖目标平台的动态库。

## Flutter 运行环境搭建与安卓打包

### 1. 安装 Flutter

请参考[官方文档](https://docs.flutter.dev/get-started/install)完成 Flutter 安装。常用步骤如下：

```bash
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"
flutter --version
```

- 建议 Flutter 版本 3.10 及以上。
- 安装 Android Studio 并配置好 Android SDK、NDK（用于 Rust FFI）。

### 2. 获取依赖

在项目根目录执行：

```bash
flutter pub get
```

### 3. 运行项目（真机或模拟器）

```bash
flutter run
```

- 首次运行会自动下载依赖和构建缓存，需耐心等待。
- 如遇权限问题，安卓需授予麦克风、存储权限。

### 4. 打包安卓 APK

```bash
flutter build apk --release
```

- 生成的 APK 路径：`build/app/outputs/flutter-apk/app-release.apk`
- 可直接安装到安卓手机测试。

### 5. 常见问题

- **NDK 配置**：如需 Rust FFI，需在 Android Studio 设置 NDK 路径，并确保 `cargo-ndk` 可用。
- **权限问题**：如录音失败，请检查应用权限设置。
- **依赖问题**：如遇依赖冲突，尝试 `flutter clean && flutter pub get`。
