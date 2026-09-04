import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'dart:async';
import 'dart:math';

// NEW PDF PACKAGES
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(const WongojiApp());
}

class WongojiApp extends StatelessWidget {
  const WongojiApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WongojiEditor(),
    );
  }
}

class WongojiTextEditingController extends TextEditingController {
  List<int> pageBreakIndices = [];
  String currentFont = 'myeongjo';

  TextStyle _getFontStyle(TextStyle? baseStyle) {
    if (currentFont == 'pen') return GoogleFonts.nanumPenScript(textStyle: baseStyle, fontSize: (baseStyle?.fontSize ?? 15) * 1.3);
    if (currentFont == 'gothic') return GoogleFonts.nanumGothic(textStyle: baseStyle);
    return GoogleFonts.nanumMyeongjo(textStyle: baseStyle);
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final activeStyle = _getFontStyle(style);
    
    if (pageBreakIndices.isEmpty) {
      return TextSpan(style: activeStyle, text: text);
    }

    List<InlineSpan> spans = [];
    int previousIndex = 0;
    int pageCounter = 2; 

    for (int breakIndex in pageBreakIndices) {
      if (breakIndex >= previousIndex && breakIndex < text.length) {
        spans.add(TextSpan(text: text.substring(previousIndex, breakIndex), style: activeStyle));
        
        if (text[breakIndex] == '\n') {
           spans.add(WidgetSpan(
             alignment: PlaceholderAlignment.middle,
             child: Container(
               margin: const EdgeInsets.symmetric(vertical: 12.0),
               child: Row(
                 children: [
                   Expanded(child: Container(height: 1.0, color: Colors.redAccent.withOpacity(0.6))),
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 12.0),
                     child: Text(
                       "p. $pageCounter",
                       style: GoogleFonts.nanumMyeongjo(
                         color: Colors.redAccent,
                         fontSize: 13,
                         fontWeight: FontWeight.bold,
                         fontStyle: FontStyle.italic,
                       ),
                     ),
                   ),
                   Expanded(child: Container(height: 1.0, color: Colors.redAccent.withOpacity(0.6))),
                 ],
               ),
             )
           ));
           previousIndex = breakIndex + 1; 
           pageCounter++;
        }
      }
    }

    if (previousIndex < text.length) {
      spans.add(TextSpan(text: text.substring(previousIndex), style: activeStyle));
    }

    return TextSpan(style: activeStyle, children: spans);
  }
}

class WongojiEditor extends StatefulWidget {
  const WongojiEditor({Key? key}) : super(key: key);

  @override
  State<WongojiEditor> createState() => _WongojiEditorState();
}

class _WongojiEditorState extends State<WongojiEditor> {
  final WongojiTextEditingController _controller = WongojiTextEditingController();
  final TextEditingController _titleController = TextEditingController(); 
  final ScrollController _scrollController = ScrollController();
  
  List<List<String>> _pages = [List.generate(200, (index) => "")];
  List<DateTime> _pageDates = [DateTime.now()]; 
  
  bool _isZoomedOut = false;
  int _themeMode = 0; 
  String _selectedFont = 'myeongjo'; // New Font State

  int _charsWithSpace = 0;
  int _charsWithoutSpace = 0;

  int _activePageIndex = 0;
  int _activeCellIndex = 0;
  double _dotX = 0.5;
  double _dotY = 0.5;
  
  bool _isTyping = false;
  bool _isDotVisible = true; 
  Timer? _cursorTimer;
  Timer? _hideDotTimer;
  bool _isInternalUpdate = false; 

  double _editorWidth = 340.0;

  final double _cellDim = 34.0;
  final double _rowGap = 12.0;
  final double _marginTop = 80.0; 
  final double _marginBottom = 40.0;
  final double _marginHorizontal = 40.0;
  final double _pageSpacing = 30.0;

  final List<String> _hintLibrary = [
    "\"글쓰기는 자신의 삶을 가꾸는 일이다.\" — 이오덕",
    "\"글은 곧 그 사람이다.\" — 신채호",
    "\"글을 쓴다는 것은 자기 자신을 온전히 대면하는 일이다.\" — 박완서",
    "\"글쓰기는 우리 자신으로부터도 우리를 해방시킵니다. 왜냐하면 글을 쓰는 동안 우리 자신이 변하기 때문입니다.\" — 김영하",
    "\"진실하게 쓰라. 너의 아픔을 숨기지 말고, 너의 기쁨을 과장하지 말라.\" — 박경리",
    "\"많이 읽고, 많이 쓰고, 많이 생각하라(삼다·三多).\" — 다산 정약용",
    "\"말하듯이 쓰라. 좋은 글은 읽을 때 말하는 것처럼 자연스럽게 흘러가야 한다.\" — 유시민",
    "\"문학을 좋아하고 시를 사랑한다는 것은 마음속에 사랑이 있다는 증거다.\" — 박목월",
    "\"글을 쓸 때는 생각이 가슴속에 꽉 차올라 넘칠 때까지 기다려야 한다. 억지로 짜낸 글은 생명력이 없다.\" — 이황(李滉)",
    "\"문장은 한 번에 이루어지지 않는다. 깎고 다듬는 고통을 거쳐야 비로소 보배로운 글이 된다.\"",
    "조용히 나 자신과 마주하는 시간",
    "기록하지 않은 기억은 흩어집니다.",
    "어떤 이야기든 좋아요. 천천히 적어보세요.",
    "망설이지 말고 첫 단어를 적어보세요.",
    "오늘은 무슨 생각이 들었나요?",
    "마음을 달래줄 따뜻한 문장을 적어보세요.",
    "당신의 글을 담고 싶습니다.",
    "언어의 바다는 넓고도 깊습니다.",
    "거창하지 않아도 아름답습니다.",
    "문장과 문장 사이, 당신의 숨결이 스며듭니다."
  ];
  late String _randomHint;

  Color get appBgColor => _themeMode == 0 ? const Color(0xFFE5E5E5) : (_themeMode == 1 ? const Color(0xFF5C5C5C) : const Color(0xFF121212));
  Color get paperColor => _themeMode == 0 ? Colors.white : (_themeMode == 1 ? const Color(0xFFBDBDBD) : Colors.black);
  Color get lineColor => _themeMode == 0 ? Colors.redAccent : (_themeMode == 1 ? const Color(0xFF858585) : const Color(0xFF424242));
  Color get textColor => _themeMode == 2 ? const Color(0xFFE0E0E0) : const Color(0xFF212121);
  Color get dotColor => _themeMode == 2 ? const Color(0xFFE0E0E0) : Colors.black;
  Color get appBarBgColor => _themeMode == 0 ? Colors.white : (_themeMode == 1 ? const Color(0xFF9E9E9E) : const Color(0xFF1E1E1E));
  Color get appBarTextColor => _themeMode == 0 ? Colors.black : (_themeMode == 1 ? Colors.black87 : Colors.white);
  Color get sidePanelBg => _themeMode == 0 ? const Color(0xFFF5F5F5) : (_themeMode == 1 ? const Color(0xFFD6D6D6) : const Color(0xFF1A1A1A));

  @override
  void initState() {
    super.initState();
    _randomHint = _hintLibrary[Random().nextInt(_hintLibrary.length)];
    _controller.addListener(_updateGrid);
    _titleController.addListener(() { setState(() {}); });
    
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!_isZoomedOut && !_isTyping) {
        setState(() {
          _isDotVisible = true; 
          bool isOccupied = false;
          if (_activePageIndex < _pages.length && _activeCellIndex < 200) {
             isOccupied = _pages[_activePageIndex][_activeCellIndex].isNotEmpty;
          }
          if (isOccupied) {
            _dotX = 0.8 + (Random().nextDouble() * 0.15); 
          } else {
            _dotX = 0.2 + (Random().nextDouble() * 0.6); 
          }
          _dotY = 0.2 + (Random().nextDouble() * 0.6); 
        });

        Timer(const Duration(milliseconds: 500), () {
          if (mounted) setState(() { _isDotVisible = false; });
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    _scrollController.dispose();
    _cursorTimer?.cancel();
    _hideDotTimer?.cancel();
    super.dispose();
  }

  // --- EXPORT FUNCTIONS ---
  void _copyToClipboard() {
    String fullText = _titleController.text.isNotEmpty 
        ? "${_titleController.text}\n\n${_controller.text}" 
        : _controller.text;
    Clipboard.setData(ClipboardData(text: fullText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('클립보드에 복사되었습니다!'),
        duration: const Duration(seconds: 2),
        backgroundColor: _themeMode == 2 ? Colors.white24 : Colors.black87,
      ),
    );
  }

  Future<void> _exportToPDF() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('PDF를 생성하는 중입니다...'),
        duration: const Duration(seconds: 2),
        backgroundColor: _themeMode == 2 ? Colors.white24 : Colors.black87,
      ),
    );

    final pdf = pw.Document();
    
    // Cloud-loading the Google Font into the PDF engine so Korean renders perfectly
    final font = await PdfGoogleFonts.nanumMyeongjoRegular();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            if (_titleController.text.isNotEmpty) ...[
              pw.Center(
                child: pw.Text(_titleController.text, style: pw.TextStyle(font: font, fontSize: 24)),
              ),
              pw.SizedBox(height: 30),
            ],
            pw.Text(
              _controller.text.replaceAll('\n', ''), // Remove artificial line breaks
              style: pw.TextStyle(font: font, fontSize: 12, lineSpacing: 10),
            ),
          ];
        },
      ),
    );

    // This native print/share API bridges smoothly from browser to local system
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'wongoji_manuscript.pdf');
  }

  void _cycleTheme() {
    setState(() { _themeMode = (_themeMode + 1) % 3; });
  }

  Widget _buildTooltip({required String message, required Widget child}) {
    return Tooltip(
      message: message,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF767676), width: 1.0),
      ),
      textStyle: const TextStyle(color: Colors.black, fontSize: 12),
      preferBelow: true,
      verticalOffset: 24,
      waitDuration: const Duration(milliseconds: 300),
      child: child,
    );
  }

  void _updateGrid() {
    if (_isInternalUpdate) return;
    
    String text = _controller.text;
    int cursorPos = _controller.selection.baseOffset;
    if (cursorPos < 0) cursorPos = text.length; 

    _charsWithSpace = text.length;
    _charsWithoutSpace = text.replaceAll(RegExp(r'\s+'), '').length;

    List<Map<String, int>> cursorMap = []; 
    List<List<String>> newPages = [];
    List<String> currentPage = List.generate(200, (index) => "");
    
    int cellIndex = 1; 
    bool isHalfFull = false; 

    bool needsTextUpdate = false;
    StringBuffer newTextBuffer = StringBuffer();
    int newCursorPos = cursorPos;
    List<int> newPageBreakIndices = [];

    void triggerPageBreak(int i) {
       newPages.add(currentPage);
       currentPage = List.generate(200, (index) => "");
       cellIndex -= 200;
       
       if (!needsTextUpdate) {
          if (i < text.length && text[i] == '\n') {
             newPageBreakIndices.add(newTextBuffer.length);
          } else {
             needsTextUpdate = true;
             newTextBuffer.write('\n'); 
             newPageBreakIndices.add(newTextBuffer.length - 1);
             if (i < text.length) newTextBuffer.write(text.substring(i));
             if (i < cursorPos) newCursorPos++; 
          }
       }
    }

    for (int i = 0; i < text.length; i++) {
      String char = text[i];
      
      while (cellIndex >= 200 && !needsTextUpdate) triggerPageBreak(i);
      if (needsTextUpdate) break;

      newTextBuffer.write(char);
      cursorMap.add({"page": newPages.length, "cell": cellIndex});
      
      bool isAlphanumeric = RegExp(r'[a-zA-Z0-9]').hasMatch(char);
      
      if (char == '\n') {
        if (isHalfFull) {
          cellIndex++;
          isHalfFull = false;
          while (cellIndex >= 200 && !needsTextUpdate) triggerPageBreak(i + 1);
        }
        int currentRow = cellIndex ~/ 20;
        cellIndex = (currentRow + 1) * 20 + 1; 
        while (cellIndex >= 200 && !needsTextUpdate) triggerPageBreak(i + 1);
        continue;
      }

      if (char == ' ') {
        if (isHalfFull) {
          cellIndex++;
          isHalfFull = false;
          while (cellIndex >= 200 && !needsTextUpdate) triggerPageBreak(i + 1);
        }
        if (cellIndex % 20 != 0) {
          currentPage[cellIndex] = char;
          cellIndex++;
        }
        continue;
      }

      if (isAlphanumeric) {
        if (isHalfFull) {
          currentPage[cellIndex] += char;
          isHalfFull = false;
          cellIndex++;
        } else {
          currentPage[cellIndex] = char;
          isHalfFull = true;
        }
      } else {
        if (isHalfFull) {
          cellIndex++;
          isHalfFull = false;
          while (cellIndex >= 200 && !needsTextUpdate) triggerPageBreak(i + 1);
        }
        currentPage[cellIndex] = char;
        cellIndex++;
      }
    }
    
    if (needsTextUpdate) {
       _isInternalUpdate = true;
       _controller.pageBreakIndices = newPageBreakIndices;
       _controller.value = TextEditingValue(
         text: newTextBuffer.toString(),
         selection: TextSelection.collapsed(offset: newCursorPos),
       );
       _isInternalUpdate = false;
       WidgetsBinding.instance.addPostFrameCallback((_) { _updateGrid(); });
       return; 
    }
    
    while (cellIndex >= 200) {
       newPages.add(currentPage);
       currentPage = List.generate(200, (index) => "");
       cellIndex -= 200;
    }
    
    cursorMap.add({"page": newPages.length, "cell": cellIndex});
    newPages.add(currentPage);

    while (_pageDates.length < newPages.length) {
      _pageDates.add(DateTime.now());
    }
    if (_pageDates.length > newPages.length) {
      _pageDates = _pageDates.sublist(0, newPages.length);
    }

    _controller.pageBreakIndices = newPageBreakIndices;
    _isTyping = true;
    _hideDotTimer?.cancel();
    _hideDotTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() { _isTyping = false; });
    });

    setState(() {
      _pages = newPages;
      if (cursorPos >= 0 && cursorPos < cursorMap.length) {
        _activePageIndex = cursorMap[cursorPos]["page"]!;
        _activeCellIndex = cursorMap[cursorPos]["cell"]!;
      }
    });
  }

  void _jumpToPage(int pageIndex) {
    setState(() {
      _isZoomedOut = false; 
    });
    
    Future.delayed(const Duration(milliseconds: 60), () {
      if (_scrollController.hasClients) {
        double exactPageHeight = (_cellDim * 10) + (_rowGap * 9) + _marginTop + _marginBottom;
        double targetOffset = pageIndex * (exactPageHeight + _pageSpacing);
        double maxScroll = _scrollController.position.maxScrollExtent;
        if (targetOffset > maxScroll) targetOffset = maxScroll;

        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Widget _buildPage(int pageIndex, double scale) {
    double paperWidth = ((_cellDim * 20) + (_marginHorizontal * 2)) * scale;
    double paperHeight = ((_cellDim * 10) + (_rowGap * 9) + _marginTop + _marginBottom) * scale;
    
    DateTime pageDate = _pageDates[pageIndex];
    String dateStr = "${pageDate.year}. ${pageDate.month.toString().padLeft(2, '0')}. ${pageDate.day.toString().padLeft(2, '0')}.";

    return Container(
      width: paperWidth,
      height: paperHeight,
      margin: EdgeInsets.only(bottom: _pageSpacing),
      decoration: BoxDecoration(
        color: paperColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_themeMode == 2 ? 0.5 : 0.15),
            blurRadius: 10 * scale,
            offset: Offset(0, 5 * scale),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: (_marginTop - 40) * scale,
            right: _marginHorizontal * scale,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "No. ${pageIndex + 1}",
                  style: GoogleFonts.nanumMyeongjo(
                    color: lineColor,
                    fontSize: 16 * scale,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  dateStr,
                  style: GoogleFonts.nanumMyeongjo(
                    color: lineColor.withOpacity(0.6),
                    fontSize: 11 * scale,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          
          if (pageIndex == 0 && _titleController.text.isNotEmpty)
            Positioned(
              top: 25 * scale,
              left: _marginHorizontal * scale,
              right: _marginHorizontal * scale,
              child: Center(
                child: Text(
                  _titleController.text,
                  style: _selectedFont == 'pen' 
                      ? GoogleFonts.nanumPenScript(fontSize: 28 * scale, color: textColor)
                      : (_selectedFont == 'gothic' 
                          ? GoogleFonts.nanumGothic(fontSize: 22 * scale, fontWeight: FontWeight.bold, color: textColor)
                          : GoogleFonts.nanumMyeongjo(fontSize: 22 * scale, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 2.0)),
                ),
              ),
            ),
          
          Positioned(
            top: _marginTop * scale,
            left: _marginHorizontal * scale,
            child: CustomPaint(
              size: Size(_cellDim * 20 * scale, ((_cellDim * 10) + (_rowGap * 9)) * scale),
              painter: WongojiPainter(
                pageData: _pages[pageIndex],
                lineColor: lineColor,
                textColor: textColor,
                scale: scale,
                activeCellIndex: _activeCellIndex,
                isCurrentPage: (pageIndex == _activePageIndex) && !_isZoomedOut && !_isTyping,
                isDotVisible: _isDotVisible,
                dotX: _dotX,
                dotY: _dotY,
                dotColor: dotColor,
                isZoomedOut: _isZoomedOut,
                selectedFont: _selectedFont, // Passing font state
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _controller.currentFont = _selectedFont; // Update the editor's text style dynamically

    return Scaffold(
      backgroundColor: appBgColor,
      appBar: AppBar(
        title: Row(
          children: [
            Text("Wongoji ", style: TextStyle(color: appBarTextColor, fontWeight: FontWeight.bold)),
            Text(
              "(공백 포함: $_charsWithSpace | 공백 제외: $_charsWithoutSpace)",
              style: TextStyle(color: appBarTextColor.withOpacity(0.7), fontSize: 14),
            ),
          ],
        ),
        backgroundColor: appBarBgColor,
        elevation: 1,
        actions: [
          _buildTooltip(
            message: "서체 변경",
            child: PopupMenuButton<String>(
              icon: Icon(Icons.font_download_outlined, color: appBarTextColor),
              onSelected: (value) {
                setState(() { _selectedFont = value; });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'myeongjo', child: Text("명조체 (기본)")),
                const PopupMenuItem(value: 'gothic', child: Text("고딕체")),
                const PopupMenuItem(value: 'pen', child: Text("손글씨 (Nanum Pen Script)")),
              ],
            ),
          ),
          _buildTooltip(
            message: "테마 변경",
            child: IconButton(
              icon: Icon(
                _themeMode == 0 ? Icons.light_mode : (_themeMode == 1 ? Icons.monochrome_photos : Icons.dark_mode)
              ),
              color: appBarTextColor,
              onPressed: _cycleTheme,
            ),
          ),
          _buildTooltip(
            message: "내보내기 및 공유",
            child: PopupMenuButton<String>(
              icon: Icon(Icons.ios_share, color: appBarTextColor),
              onSelected: (value) {
                if (value == 'copy') _copyToClipboard();
                if (value == 'pdf') _exportToPDF();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'copy', child: Text("클립보드로 복사")),
                const PopupMenuItem(value: 'pdf', child: Text("PDF로 내보내기")),
              ],
            ),
          ),
          _buildTooltip(
            message: _isZoomedOut ? "편집기로 돌아가기" : "모든 페이지 보기",
            child: IconButton(
              icon: Icon(_isZoomedOut ? Icons.zoom_in : Icons.grid_view),
              color: appBarTextColor,
              onPressed: () {
                setState(() { _isZoomedOut = !_isZoomedOut; });
              },
            ),
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch, 
            children: [
              Expanded(
                child: _isZoomedOut
                    ? GridView.builder(
                        padding: const EdgeInsets.all(40),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, 
                          crossAxisSpacing: 40,
                          mainAxisSpacing: 40,
                          childAspectRatio: 1.45, 
                        ),
                        itemCount: _pages.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => _jumpToPage(index),
                            child: Center(child: _buildPage(index, 0.65)),
                          );
                        },
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 20),
                        itemCount: _pages.length,
                        itemBuilder: (context, index) {
                          return Center(child: _buildPage(index, 1.0));
                        },
                      ),
              ),
              
              if (!_isZoomedOut) ...[
                MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      setState(() {
                        _editorWidth -= details.delta.dx;
                        double maxAllowedEditorWidth = constraints.maxWidth - 800.0;
                        _editorWidth = _editorWidth.clamp(
                          340.0, 
                          max(340.0, maxAllowedEditorWidth)
                        );
                      });
                    },
                    child: Container(
                      width: 12.0, 
                      color: sidePanelBg,
                      child: Center(
                        child: Container(
                          width: 2.0,
                          height: 40.0, 
                          decoration: BoxDecoration(
                            color: lineColor.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(2.0),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: _editorWidth, 
                  color: sidePanelBg,
                  padding: const EdgeInsets.only(top: 24.0, right: 24.0, bottom: 24.0, left: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _titleController,
                        style: _selectedFont == 'pen' 
                            ? GoogleFonts.nanumPenScript(fontSize: 28, color: textColor)
                            : (_selectedFont == 'gothic' 
                                ? GoogleFonts.nanumGothic(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)
                                : GoogleFonts.nanumMyeongjo(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: "제목",
                          hintStyle: GoogleFonts.nanumMyeongjo(
                            color: textColor.withOpacity(0.3),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Divider(color: lineColor.withOpacity(0.2)),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          maxLines: null,
                          minLines: null, 
                          expands: true,
                          autofocus: true,
                          style: _selectedFont == 'pen' 
                              ? GoogleFonts.nanumPenScript(fontSize: 23, color: textColor, height: 1.5)
                              : (_selectedFont == 'gothic' 
                                  ? GoogleFonts.nanumGothic(fontSize: 17, color: textColor, height: 1.8)
                                  : GoogleFonts.nanumMyeongjo(fontSize: 18, color: textColor, height: 1.8)),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: _randomHint, 
                            hintStyle: GoogleFonts.nanumMyeongjo(
                              color: textColor.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        }
      ),
    );
  }
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
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cellDim = 34.0 * scale;
    final double rowGap = 12.0 * scale;

    final paintLine = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0 * scale
      ..style = PaintingStyle.stroke;

    canvas.drawRect(Rect.fromLTWH(0, 0, cellDim * 20, (cellDim * 10) + (rowGap * 9)), paintLine);

    for (int row = 0; row < 10; row++) {
      double y = row * (cellDim + rowGap);

      if (row < 9) {
         canvas.drawLine(Offset(0, y + cellDim), Offset(cellDim * 20, y + cellDim), paintLine);
         canvas.drawLine(Offset(0, y + cellDim + rowGap), Offset(cellDim * 20, y + cellDim + rowGap), paintLine);
      }

      for (int col = 0; col < 20; col++) {
        double x = col * cellDim;

        if (col < 19) {
          canvas.drawLine(Offset(x + cellDim, y), Offset(x + cellDim, y + cellDim), paintLine);
        }

        int cellIndex = (row * 20) + col;
        String char = pageData[cellIndex];

        if (char.isNotEmpty) {
          TextStyle getTextStyle() {
            double fontSize = 15 * scale;
            FontWeight weight = isZoomedOut ? FontWeight.w700 : FontWeight.w500;
            
            if (selectedFont == 'pen') {
               return GoogleFonts.nanumPenScript(fontSize: fontSize * 1.3, color: textColor, fontWeight: weight);
            } else if (selectedFont == 'gothic') {
               return GoogleFonts.nanumGothic(fontSize: fontSize, color: textColor, fontWeight: weight);
            }
            return GoogleFonts.nanumMyeongjo(fontSize: fontSize, color: textColor, fontWeight: weight);
          }

          TextSpan span = TextSpan(style: getTextStyle(), text: char);
          TextPainter tp = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
          tp.layout();
          
          double tx = x + (cellDim - tp.width) / 2;
          double ty = y + (cellDim - tp.height) / 2;
          tp.paint(canvas, Offset(tx, ty));
        }

        if (isCurrentPage && cellIndex == activeCellIndex && isDotVisible) {
          final dotPaint = Paint()..color = dotColor..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(x + (cellDim * dotX), y + (cellDim * dotY)), 1.79 * scale, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant WongojiPainter oldDelegate) {
    return true; 
  }
}