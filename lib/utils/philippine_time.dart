// Philippine Standard Time is a fixed UTC+8 with no daylight saving, so a
// plain offset is correct year-round without pulling in the `timezone`
// package's IANA database.
const philippineTimeOffset = Duration(hours: 8);

extension PhilippineTime on DateTime {
  DateTime get toPhilippineTime => toUtc().add(philippineTimeOffset);
}
