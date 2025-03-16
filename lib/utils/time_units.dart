enum TimeUnit {
  minutes,
  hours,
  days;

  String get label {
    switch (this) {
      case TimeUnit.minutes:
        return 'دقيقة';
      case TimeUnit.hours:
        return 'ساعة';
      case TimeUnit.days:
        return 'يوم';
    }
  }

  String get pluralLabel {
    switch (this) {
      case TimeUnit.minutes:
        return 'دقائق';
      case TimeUnit.hours:
        return 'ساعات';
      case TimeUnit.days:
        return 'أيام';
    }
  }

  int toMinutes(int value) {
    switch (this) {
      case TimeUnit.minutes:
        return value;
      case TimeUnit.hours:
        return value * 60;
      case TimeUnit.days:
        return value * 24 * 60;
    }
  }

  Duration toDuration(int value) {
    switch (this) {
      case TimeUnit.minutes:
        return Duration(minutes: value);
      case TimeUnit.hours:
        return Duration(hours: value);
      case TimeUnit.days:
        return Duration(days: value);
    }
  }
}