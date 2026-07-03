enum LocationContext { home, work, outside }

extension LocationContextLabel on LocationContext {
  String get label {
    switch (this) {
      case LocationContext.home:
        return 'Home';
      case LocationContext.work:
        return 'Work';
      case LocationContext.outside:
        return 'Outside';
    }
  }

  String get wireValue {
    switch (this) {
      case LocationContext.home:
        return 'home';
      case LocationContext.work:
        return 'work';
      case LocationContext.outside:
        return 'outside';
    }
  }
}
