/// `true`, sobald `Purchases.configure` erfolgreich lief. Jeder `Purchases.*`-
/// Aufruf muss davon abhängen: ohne konfigurierte Instanz wirft das native SDK
/// ("There is no singleton instance") und beendet die App (#454).
bool revenueCatConfigured = false;
