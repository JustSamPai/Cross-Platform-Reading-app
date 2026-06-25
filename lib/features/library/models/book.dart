class Book {
  const Book({
    required this.title,
    required this.author,
    required this.totalPages,
    required this.currentPage,
    required this.tags,
  });

  final String title;
  final String author;
  final int totalPages;
  final int currentPage;
  final List<String> tags;

  double get progress {
    if (totalPages == 0) {
      return 0;
    }
    return (currentPage / totalPages).clamp(0, 1).toDouble();
  }

  int get progressPercent => (progress * 100).round();

  int get remainingPages =>
      (totalPages - currentPage).clamp(0, totalPages).toInt();
}
