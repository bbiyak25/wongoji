import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../models/manuscript.dart';
import 'wongoji_painters.dart';

class DocumentCard extends StatelessWidget {
  final Manuscript doc;
  final VoidCallback onTap;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;
  final bool isTrashMode;

  const DocumentCard({
    Key? key, 
    required this.doc, 
    required this.onTap, 
    required this.onUpdate, 
    required this.onDelete, 
    required this.isTrashMode
  }) : super(key: key);

  void _editTitleDialog(BuildContext context) {
    TextEditingController tempCtrl = TextEditingController(text: doc.title);
    
    void saveAndClose() {
      doc.title = tempCtrl.text.trim();
      onUpdate(); 
      Navigator.pop(context);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text("제목 수정", style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold, color: Colors.black87)),
          content: TextField(
            controller: tempCtrl,
            autofocus: true,
            style: GoogleFonts.nanumMyeongjo(color: Colors.black87),
            decoration: InputDecoration(
              hintText: "새 제목을 입력하세요",
              hintStyle: GoogleFonts.nanumMyeongjo(color: Colors.grey.shade400),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
            ),
            onSubmitted: (_) => saveAndClose(), 
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("취소", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: saveAndClose,
              child: const Text("확인", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    String subtitleStr = isTrashMode && doc.deletedAt != null 
        ? "영구 삭제까지 ${max(0, 3 - DateTime.now().difference(doc.deletedAt!).inDays)}일 남음"
        : "${doc.pageCount}쪽 • ${doc.lastModified.year}.${doc.lastModified.month.toString().padLeft(2, '0')}.${doc.lastModified.day.toString().padLeft(2, '0')}";

    String displayTitle = doc.title.trim().isNotEmpty ? doc.title : "제목 없음";

    return Column(
      children: [
        // 1. Vertical Cover Art 
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1 / 1.414,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  // We moved the decoration (background color & shadow) to the OUTER container
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDFBF7), 
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(2, 4),
                      )
                    ],
                  ),
                  // The stack now lives inside the safely-sized container!
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: MinimalCoverPainter(
                            title: displayTitle,
                            fontFamily: doc.font,
                            lineColor: Colors.redAccent.withOpacity(0.6),
                            textColor: const Color(0xFF212121),
                          ),
                        ),
                      ),
                      
                      // The Trash Delete Icon
                      if (!isTrashMode)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: onDelete,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.delete_outline, size: 16, color: Colors.grey.shade700),
                            ),
                          ),
                        )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // 2. Title with Pencil Button
        SizedBox(
          height: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nanumMyeongjo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              if (!isTrashMode) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _editTitleDialog(context),
                  child: Icon(Icons.edit, size: 16, color: Colors.grey.shade500),
                )
              ]
            ],
          ),
        ),
        const SizedBox(height: 4),
        
        // 3. Subtitle
        Text(
          subtitleStr,
          style: GoogleFonts.nanumMyeongjo(
            fontSize: 13, 
            color: isTrashMode ? Colors.redAccent.withOpacity(0.8) : Colors.grey.shade500
          ),
        ),
      ],
    );
  }
}