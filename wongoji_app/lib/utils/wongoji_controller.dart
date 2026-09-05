import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WongojiTextEditingController extends TextEditingController {
  List<int> pageBreakIndices = [];
  String currentFont = 'myeongjo';

  TextStyle _getFontStyle(TextStyle? baseStyle) {
    final fallback = const ['Apple SD Gothic Neo', 'Malgun Gothic', 'sans-serif'];
    if (currentFont == 'pen') return GoogleFonts.nanumPenScript(textStyle: baseStyle, fontSize: (baseStyle?.fontSize ?? 15) * 1.3).copyWith(fontFamilyFallback: fallback);
    if (currentFont == 'gothic') return GoogleFonts.nanumGothic(textStyle: baseStyle).copyWith(fontFamilyFallback: fallback);
    return GoogleFonts.nanumMyeongjo(textStyle: baseStyle).copyWith(fontFamilyFallback: fallback);
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final activeStyle = _getFontStyle(style);
    
    if (pageBreakIndices.isEmpty) return TextSpan(style: activeStyle, text: text);

    List<InlineSpan> spans = [];
    int previousIndex = 0;
    int pageCounter = 2; 

    for (int breakIndex in pageBreakIndices) {
      if (breakIndex >= previousIndex && breakIndex <= text.length) {
        spans.add(TextSpan(text: text.substring(previousIndex, breakIndex), style: activeStyle));
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 20.0),
            child: Row(
              children: [
                Expanded(child: Container(height: 1.0, color: Colors.redAccent.withOpacity(0.4))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    "p. $pageCounter",
                    style: GoogleFonts.nanumMyeongjo(
                      color: Colors.redAccent.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                Expanded(child: Container(height: 1.0, color: Colors.redAccent.withOpacity(0.4))),
              ],
            ),
          )
        ));
        previousIndex = breakIndex; 
        pageCounter++;
      }
    }
    if (previousIndex < text.length) {
      spans.add(TextSpan(text: text.substring(previousIndex), style: activeStyle));
    }
    return TextSpan(style: activeStyle, children: spans);
  }
}