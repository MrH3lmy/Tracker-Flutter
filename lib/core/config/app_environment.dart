enum AppEnvironment {
  local,
  development,
  staging,
  production;

  static AppEnvironment fromName(String name) => AppEnvironment.values
      .firstWhere((e) => e.name == name, orElse: () => AppEnvironment.local);
}
