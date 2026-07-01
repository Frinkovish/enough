enum LocationContext { home, work }

extension LocationContextLabel on LocationContext {
  String get label {
    switch (this) {
      case LocationContext.home:
        return 'Home';
      case LocationContext.work:
        return 'Work';
    }
  }

  String get wireValue {
    switch (this) {
      case LocationContext.home:
        return 'home';
      case LocationContext.work:
        return 'work';
    }
  }
}
