import 'package:flutter_test/flutter_test.dart';
import '../../library/utils/reading_time_estimator.dart';

class ReadingTimeEstimator {
  const ReadingTimeEstimator({
    this.wordsPerMinute = 400,
    this.minimumSeconds = 5,
    this.maximumSeconds = 180,
  });

  final int wordsPerMinute;
  final int minimumSeconds;
  final int maximumSeconds;

  int wordCount(String text) {
    return RegExp(r"[A-Za-z0-9]+(?:['’-][A-Za-z0-9]+)?")
        .allMatches(text)
        .length;
  }

  int requiredSecondsForText(String text) {
    final words = wordCount(text);

    if (words <= 0) {
      return minimumSeconds;
    }

    final seconds = ((words / wordsPerMinute) * 60).ceil();

    return seconds.clamp(minimumSeconds, maximumSeconds).toInt();
  }
}