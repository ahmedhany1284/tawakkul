enum TimeUnit {
  seconds,
  minutes,
  hours,
  days;

  String get label {
    switch (this) {
      case TimeUnit.seconds:
        return 'ثانية';
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
      case TimeUnit.seconds:
        return 'ثواني';
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
      case TimeUnit.seconds:
        return (value / 60).ceil();
      case TimeUnit.minutes:
        return value;
      case TimeUnit.hours:
        return value * 60;
      case TimeUnit.days:
        return value * 24 * 60;
    }
  }
}