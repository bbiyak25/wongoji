class Manuscript {
  final String id;
  String title;
  String content;
  String font;
  DateTime lastModified;
  int pageCount; 
  DateTime? deletedAt; 
  int targetLength; // Stores the target character count

  Manuscript({
    required this.id,
    this.title = '',
    this.content = '',
    this.font = 'myeongjo',
    required this.lastModified,
    this.pageCount = 1,
    this.deletedAt,
    this.targetLength = 0, // 0 means the limit is turned off
  });
}