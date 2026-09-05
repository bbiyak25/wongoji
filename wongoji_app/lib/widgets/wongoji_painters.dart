import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MinimalCoverPainter extends CustomPainter {
  final String title;
  final String fontFamily;
  final Color lineColor;
  final Color textColor;

  MinimalCoverPainter({required this.title, required this.fontFamily, required this.lineColor, required this.textColor});

  TextStyle getTextStyle(String fontType, double fontSize, Color color) {
    final fallback = const ['Apple SD Gothic Neo', 'Malgun Gothic', 'sans-serif'];
    if (fontType == 'pen') return GoogleFonts.nanumPenScript(fontSize: fontSize * 1.5, color: color, fontWeight: FontWeight.bold).copyWith(fontFamilyFallback: fallback);
    if (fontType == 'gothic') return GoogleFonts.nanumGothic(fontSize: fontSize, color: color, fontWeight: FontWeight.bold).copyWith(fontFamilyFallback: fallback);
    return GoogleFonts.nanumMyeongjo(fontSize: fontSize, color: color, fontWeight: FontWeight.w900).copyWith(fontFamilyFallback: fallback);
  }

  @override
  void paint(Canvas canvas, Size size) {
    String cleanTitle = title.trim(); 
    if (cleanTitle.isEmpty) cleanTitle = "제목없음";

    int maxRows = 8; 
    int cols = (cleanTitle.length / maxRows).ceil().clamp(1, 4); 

    double cellDim = 24.0; 
    double gridW = cols * cellDim;
    double gridH = maxRows * cellDim;

    double startX = (size.width - gridW) / 2;
    double startY = (size.height - gridH) / 2;

    final paintLine = Paint()..color = lineColor..strokeWidth = 0.8..style = PaintingStyle.stroke;

    canvas.drawRect(Rect.fromLTWH(startX, startY, gridW, gridH), paintLine);

    for(int i = 1; i < cols; i++) canvas.drawLine(Offset(startX + (i * cellDim), startY), Offset(startX + (i * cellDim), startY + gridH), paintLine);
    for(int i = 1; i < maxRows; i++) canvas.drawLine(Offset(startX, startY + (i * cellDim)), Offset(startX + gridW, startY + (i * cellDim)), paintLine);

    for(int c = 0; c < cols; c++) {
       for(int r = 0; r < maxRows; r++) {
          int stringIndex = c * maxRows + r;
          int visualCol = (cols - 1) - c; 
          
          if (stringIndex < cleanTitle.length) {
             String char = cleanTitle[stringIndex];
             TextSpan span = TextSpan(style: getTextStyle(fontFamily, cellDim * 0.65, textColor), text: char);
             TextPainter tp = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr)..layout();
             
             double tx = startX + (visualCol * cellDim) + (cellDim - tp.width) / 2;
             double ty = startY + (r * cellDim) + (cellDim - tp.height) / 2;
             tp.paint(canvas, Offset(tx, ty));
          }
       }
    }
  }
  @override
  bool shouldRepaint(covariant MinimalCoverPainter oldDelegate) => true;
}

class WongojiPainter extends CustomPainter {
  final List<String> pageData;
  final Color lineColor;
  final Color textColor;
  final double scale;
  final int activeCellIndex;
  final bool isCurrentPage;
  final bool isDotVisible;
  final double dotX;
  final double dotY;
  final Color dotColor;
  final bool isZoomedOut; 
  final String selectedFont;
  
  final int pageIndex;
  final int targetLength;

  WongojiPainter({
    required this.pageData, 
    required this.lineColor, 
    required this.textColor, 
    required this.scale, 
    required this.activeCellIndex, 
    required this.isCurrentPage, 
    required this.isDotVisible, 
    required this.dotX, 
    required this.dotY, 
    required this.dotColor, 
    required this.isZoomedOut, 
    required this.selectedFont,
    required this.pageIndex,
    required this.targetLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cellDim = 34.0 * scale;
    final double rowGap = 12.0 * scale;

    // 1. PRE-PASS: Draw the ±10% Highlighter Safe Zone UNDER the grid
    if (targetLength > 0) {
      int minSafe = (targetLength * 0.9).floor();
      int maxSafe = (targetLength * 1.1).ceil();
      Color highlightColor = lineColor == Colors.redAccent ? const Color(0xFFFFD54F).withOpacity(0.25) : Colors.blueGrey.withOpacity(0.3);

      for (int row = 0; row < 10; row++) {
        double y = row * (cellDim + rowGap);
        for (int col = 0; col < 20; col++) {
          double x = col * cellDim;
          int absoluteIndex = (pageIndex * 200) + (row * 20) + col;
          
          if (absoluteIndex >= minSafe && absoluteIndex <= maxSafe) {
            canvas.drawRect(Rect.fromLTWH(x, y, cellDim, cellDim), Paint()..color = highlightColor..style = PaintingStyle.fill);
          }
        }
      }
    }

    // 2. Draw Grid Lines
    final paintLine = Paint()..color = lineColor..strokeWidth = 1.0 * scale..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(0, 0, cellDim * 20, (cellDim * 10) + (rowGap * 9)), paintLine);

    for (int row = 0; row < 10; row++) {
      double y = row * (cellDim + rowGap);
      if (row < 9) {
         canvas.drawLine(Offset(0, y + cellDim), Offset(cellDim * 20, y + cellDim), paintLine);
         canvas.drawLine(Offset(0, y + cellDim + rowGap), Offset(cellDim * 20, y + cellDim + rowGap), paintLine);
      }
      for (int col = 0; col < 20; col++) {
        double x = col * cellDim;
        if (col < 19) canvas.drawLine(Offset(x + cellDim, y), Offset(x + cellDim, y + cellDim), paintLine);

        // 3. Draw Text
        int cellIndex = (row * 20) + col;
        String char = pageData[cellIndex];

        if (char.isNotEmpty) {
          TextStyle getTextStyle() {
            double fontSize = 15 * scale;
            FontWeight weight = isZoomedOut ? FontWeight.w700 : FontWeight.w500;
            final fallback = const ['Apple SD Gothic Neo', 'Malgun Gothic', 'sans-serif'];
            if (selectedFont == 'pen') return GoogleFonts.nanumPenScript(fontSize: fontSize * 1.3, color: textColor, fontWeight: weight).copyWith(fontFamilyFallback: fallback);
            if (selectedFont == 'gothic') return GoogleFonts.nanumGothic(fontSize: fontSize, color: textColor, fontWeight: weight).copyWith(fontFamilyFallback: fallback);
            return GoogleFonts.nanumMyeongjo(fontSize: fontSize, color: textColor, fontWeight: weight).copyWith(fontFamilyFallback: fallback);
          }

          TextSpan span = TextSpan(style: getTextStyle(), text: char);
          TextPainter tp = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr)..layout();
          tp.paint(canvas, Offset(x + (cellDim - tp.width) / 2, y + (cellDim - tp.height) / 2));
        }

        // Focus Dot
        if (isCurrentPage && cellIndex == activeCellIndex && isDotVisible) {
          final dotPaint = Paint()..color = dotColor..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(x + (cellDim * dotX), y + (cellDim * dotY)), 1.79 * scale, dotPaint);
        }

        // 4. POST-PASS: Draw the Bold Red End-Mark ON TOP of everything
        int absoluteIndex = (pageIndex * 200) + cellIndex;
        if (targetLength > 0 && absoluteIndex == targetLength - 1) {
          final targetLinePaint = Paint()..color = Colors.redAccent..strokeWidth = 3.5 * scale..style = PaintingStyle.stroke;
          canvas.drawLine(Offset(x + cellDim, y), Offset(x + cellDim, y + cellDim), targetLinePaint);
        }
      }
    }
  }
  @override
  bool shouldRepaint(covariant WongojiPainter oldDelegate) => true; 
}