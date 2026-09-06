// Convert Manuscript to Firestore format
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'font': font,
      'lastModified': lastModified.toIso8601String(),
      'pageCount': pageCount,
      'targetLength': targetLength,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  // Create Manuscript from Firestore format
  factory Manuscript.fromMap(Map<String, dynamic> map, String documentId) {
    return Manuscript(
      id: documentId,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      font: map['font'] ?? 'myeongjo',
      lastModified: DateTime.tryParse(map['lastModified'] ?? '') ?? DateTime.now(),
      pageCount: map['pageCount'] ?? 1,
      targetLength: map['targetLength'] ?? 0,
    )..deletedAt = map['deletedAt'] != null ? DateTime.tryParse(map['deletedAt']) : null;
  }