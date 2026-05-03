/// Konfiguration für Google Sign-In.
///
/// Wichtig:
/// - Trage hier die "Web-Client-ID" aus der Google Cloud Console ein
///   (OAuth 2.0-Client-Typ: Webanwendung).
/// - Ohne diese ID schlägt GoogleSignIn.authenticate() auf Android fehl.
class GoogleSignInConfig {
  static const String serverClientId = '915742606352-rsrquuo91q9jk44avt26fklgdb9hv7ho.apps.googleusercontent.com';
}
