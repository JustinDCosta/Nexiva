String minuteToLabel(int minuteOfDay) {
  final h = (minuteOfDay ~/ 60).toString().padLeft(2, "0");
  final m = (minuteOfDay % 60).toString().padLeft(2, "0");
  return "$h:$m";
}
