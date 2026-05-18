/// Giphy API key for chat GIF / sticker picker.
///
/// Set via `--dart-define=GIPHY_API_KEY=your_key` at build/run time.
class GiphyConfig {
  const GiphyConfig({required this.apiKey});

  final String apiKey;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  static GiphyConfig fromEnvironment() {
    const fromDefine = String.fromEnvironment('GIPHY_API_KEY');
    return GiphyConfig(apiKey: fromDefine.trim());
  }
}
