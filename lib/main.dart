import 'bootstrap.dart';
import 'core/config/app_environment.dart';

/// Default entry point — local development against a co-located
/// Tracker-BE instance. Use the `main_*.dart` flavor entry points (or pass
/// `--dart-define=API_BASE_URL=...`) to target another environment.
void main() => bootstrap(AppEnvironment.local);
