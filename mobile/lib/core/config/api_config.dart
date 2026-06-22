/// Basis-URL der .NET-Backend-API.
///
/// Über `--dart-define=API_URL=...` überschreibbar (z. B. Produktion/Staging).
/// Default zeigt auf den lokalen Backend-Dev-Server; `10.0.2.2` ist der Host
/// aus Sicht des Android-Emulators (entspricht `localhost` des Entwicklerrechners).
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:5148',
  );
}
