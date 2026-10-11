/// Single source of "now" so tests and screenshots can pin the time.
library;

DateTime Function() _now = DateTime.now;

DateTime clockNow() => _now();

/// Pins the clock (pass null to restore the system clock).
void setClockForTesting(DateTime? fixed) {
  _now = fixed == null ? DateTime.now : () => fixed;
}
