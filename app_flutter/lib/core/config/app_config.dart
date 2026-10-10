/// Configuración de compilación.
///
/// `flutter run --dart-define=API_MODE=fake` activa el modo simulado
/// (sin red, con fixtures locales). Por defecto se usa el servicio real.
class AppConfig {
  static const String apiMode = String.fromEnvironment(
    'API_MODE',
    defaultValue: 'real',
  );

  static const bool useFakeApi = apiMode == 'fake';

  const AppConfig._();
}
