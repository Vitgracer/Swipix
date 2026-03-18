import 'package:path/path.dart' as p;

class ReliableDateResult {
  final DateTime date;
  final bool isUnknown;

  ReliableDateResult(this.date, this.isUnknown);
}

class PhotoMetadataService {
  static final List<RegExp> _fileNameDatePatterns = [
    RegExp(r'(\d{4})(\d{2})(\d{2})_\d{6}'),
    RegExp(r'(\d{4})(\d{2})(\d{2})-WA'),
    RegExp(r'(\d{4})(\d{2})(\d{2})[-_]\d{6}'),
    RegExp(r'(\d{4})-(\d{2})-(\d{2})-\d{2}-\d{2}-\d{2}'),
    RegExp(r'(20\d{2})(\d{2})(\d{2})'),
  ];

  /// FAST version: Uses system metadata and filename.
  /// Suspicious threshold: if created in the last 30 days but no date in filename.
  ReliableDateResult getFastReliableDate({
    required String fileName,
    required DateTime systemDate,
  }) {
    // 1. Try Filename parsing (Highest priority)
    final DateTime? fileNameDate = _getDateTimeFromFileName(fileName);
    if (fileNameDate != null) {
      return ReliableDateResult(fileNameDate, false);
    }

    // 2. Try Timestamp from filename
    final DateTime? timestampDate = _getDateTimeFromTimestamp(fileName);
    if (timestampDate != null) {
      return ReliableDateResult(timestampDate, false);
    }

    // 3. Check for "suspicious" recent dates (e.g., copied in the last 30 days)
    final now = DateTime.now();
    final difference = now.difference(systemDate).inDays;

    // If file was "created" in the last 30 days but name is generic (e.g. 1.jpg, photo.png)
    // we mark it as unknown because it's likely a recent copy of an old file.
    if (difference <= 30) {
      return ReliableDateResult(systemDate, true);
    }

    // For older files, we trust the system date
    return ReliableDateResult(systemDate, false);
  }

  DateTime? _getDateTimeFromFileName(String fileName) {
    for (var pattern in _fileNameDatePatterns) {
      final match = pattern.firstMatch(fileName);
      if (match != null && match.groupCount >= 3) {
        try {
          final year = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          final day = int.parse(match.group(3)!);
          if (month >= 1 && month <= 12 && day >= 1 && day <= 31 && year > 1990 && year <= DateTime.now().year) {
            return DateTime(year, month, day);
          }
        } catch (_) {}
      }
    }
    return null;
  }

  DateTime? _getDateTimeFromTimestamp(String fileName) {
    final nameOnly = p.withoutExtension(fileName);
    if (RegExp(r'^\d{10,13}$').hasMatch(nameOnly)) {
      try {
        final timestamp = int.parse(nameOnly);
        DateTime date = nameOnly.length == 13 
          ? DateTime.fromMillisecondsSinceEpoch(timestamp) 
          : DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        if (date.year > 1990 && date.year <= DateTime.now().year) return date;
      } catch (_) {}
    }
    return null;
  }
}
