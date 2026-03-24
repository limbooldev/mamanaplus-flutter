import 'package:mamana_plus/shared/ui/ui.dart';

// TODO: Domain / data / presentation layers under lib/features/chat/.

/// Verifies chat → shared UI dependency direction.
class ChatHealth {
  bool get ok => UiHealth().ok;
}
