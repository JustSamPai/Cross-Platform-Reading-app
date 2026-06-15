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
    return currentPage / totalPages;
  }
}
