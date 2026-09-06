import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../models/manuscript.dart';

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
    this.isTrashMode = false,
  }) : super(key: key);

  void _showRenameDialog(BuildContext context) {
    TextEditingController controller = TextEditingController(text: doc.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text("제목 수정", style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent))),
          style: GoogleFonts.nanumMyeongjo(fontSize: 18),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              doc.title = controller.text;
              doc.lastModified = DateTime.now();
              onUpdate();
              Navigator.pop(ctx);
            },
            child: const Text("확인", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = "${doc.lastModified.year}.${doc.lastModified.month.toString().padLeft(2, '0')}.${doc.lastModified.day.toString().padLeft(2, '0')}";
    
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.414,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _MiniHorizontalWongojiPainter(doc.title.isEmpty ? "제목 없음" : doc.title),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: Icon(
                            isTrashMode ? Icons.restore : Icons.delete_outline,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          onPressed: onDelete,
                          splashRadius: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _showRenameDialog(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  doc.title.isEmpty ? "제목 없음" : doc.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nanumMyeongjo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.edit, size: 14, color: Colors.grey.shade500),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "${doc.pageCount}쪽 • $formattedDate",
          style: GoogleFonts.nanumMyeongjo(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _MiniHorizontalWongojiPainter extends CustomPainter {
  final String title;

  _MiniHorizontalWongojiPainter(this.title);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE57373).withOpacity(0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // 👉 1. Enforce 40 character maximum and inject ".." if it exceeds
    String displayTitle = title;
    if (displayTitle.length > 40) {
      displayTitle = "${displayTitle.substring(0, 38)}..";
    }

    int maxPerRow = 10;
    List<String> rows = [];
    for (int i = 0; i < displayTitle.length; i += maxPerRow) {
      rows.add(displayTitle.substring(i, min(i + maxPerRow, displayTitle.length)));
    }

    double cellDim = size.width / 14;
    if (cellDim > 28) cellDim = 28;
    double rowGap = 8.0;

    double totalHeight = rows.length * cellDim + (rows.length - 1) * rowGap;
    double startY = (size.height - totalHeight) / 2; 

    for (int r = 0; r < rows.length; r++) {
      String rowText = rows[r];
      
      // 👉 2. Force the row to ALWAYS draw 10 boxes, regardless of text length
      double rowWidth = maxPerRow * cellDim;
      double startX = (size.width - rowWidth) / 2; 
      double y = startY + (r * (cellDim + rowGap));

      // Draw the outer continuous row box
      canvas.drawRect(Rect.fromLTWH(startX, y, rowWidth, cellDim), paint);

      // Draw the 9 inner vertical dividers to make 10 boxes
      for (int c = 1; c < maxPerRow; c++) {
        double divX = startX + (c * cellDim);
        canvas.drawLine(Offset(divX, y), Offset(divX, y + cellDim), paint);
      }

      // Draw the characters sequentially inside the boxes
      for (int c = 0; c < rowText.length; c++) {
        String char = rowText[c];
        if (char.trim().isNotEmpty || char == '.') {
          textPainter.text = TextSpan(
            text: char,
            style: GoogleFonts.nanumMyeongjo(
              color: Colors.black87,
              fontSize: cellDim * 0.65,
              fontWeight: FontWeight.bold,
            ),
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(
              (startX + c * cellDim) + (cellDim - textPainter.width) / 2,
              y + (cellDim - textPainter.height) / 2,
            ),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}