import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'dart:async';
import 'dart:math';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/manuscript.dart';
import '../utils/wongoji_controller.dart';
import '../widgets/wongoji_painters.dart';
import '../utils/achievement_manager.dart';
import '../main.dart'; 

class WongojiEditorPaper extends StatefulWidget {
  final Manuscript initialDocument;
  const WongojiEditorPaper({Key? key, required this.initialDocument}) : super(key: key);
  @override
  State<WongojiEditorPaper> createState() => _WongojiEditorPaperState();
}

class _WongojiEditorPaperState extends State<WongojiEditorPaper> {
  final DateTime _sessionStartTime = DateTime.now(); 
  
  final FocusNode _hiddenFocusNode = FocusNode();
  
  final WongojiTextEditingController _controller = WongojiTextEditingController();
  final TextEditingController _titleController = TextEditingController(); 
  final ScrollController _scrollController = ScrollController();
  
  // 👉 GOD MODE: New Variables for the Split Screen
  final ScrollController _editorScrollController = ScrollController();
  bool _isSplitMode = false;
  double _editorWidth = 340.0;
  late String _randomHint;
  
  List<List<String>> _pages = [List.generate(200, (index) => "")];
  List<DateTime> _pageDates = [DateTime.now()]; 
  
  List<Map<String, int>> _cursorMap = [];
  int _dragBaseOffset = -1;

  bool _isZoomedOut = false;
  String _selectedFont = 'myeongjo'; 
  int _targetLength = 0;
  int _targetPageIndex = 0; 

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
    "\"글쓰기는 우리 자신으로부터도 보리를 해방시킵니다. 왜냐하면 글을 쓰는 동안 우리 자신이 변하기 때문입니다.\" — 김영하",
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

  @override
  void initState() {
    super.initState();
    _randomHint = _hintLibrary[Random().nextInt(_hintLibrary.length)];
    _titleController.text = widget.initialDocument.title;
    _controller.text = widget.initialDocument.content;
    _selectedFont = widget.initialDocument.font;
    _targetLength = widget.initialDocument.targetLength;

    _controller.addListener(_updateGrid);
    _titleController.addListener(() { setState(() {}); });
    
    WidgetsBinding.instance.addPostFrameCallback((_) { 
      _updateGrid(); 
      _hiddenFocusNode.requestFocus(); 
    });

    _cursorTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!_isZoomedOut && !_isTyping) {
        setState(() {
          _isDotVisible = true; 
          bool isOccupied = false;
          if (_activePageIndex < _pages.length && _activeCellIndex < 200) {
             isOccupied = _pages[_activePageIndex][_activeCellIndex].isNotEmpty;
          }
          
          if (isOccupied) {
            int corner = Random().nextInt(4);
            switch (corner) {
              case 0: 
                _dotX = 0.05 + (Random().nextDouble() * 0.2);
                _dotY = 0.05 + (Random().nextDouble() * 0.2);
                break;
              case 1: 
                _dotX = 0.75 + (Random().nextDouble() * 0.2);
                _dotY = 0.05 + (Random().nextDouble() * 0.2);
                break;
              case 2: 
                _dotX = 0.05 + (Random().nextDouble() * 0.2);
                _dotY = 0.75 + (Random().nextDouble() * 0.2);
                break;
              case 3: 
                _dotX = 0.75 + (Random().nextDouble() * 0.2);
                _dotY = 0.75 + (Random().nextDouble() * 0.2);
                break;
            }
          } else {
            _dotX = 0.2 + (Random().nextDouble() * 0.6); 
            _dotY = 0.2 + (Random().nextDouble() * 0.6); 
          }
        });

        Timer(const Duration(milliseconds: 500), () {
          if (mounted) setState(() { _isDotVisible = false; });
        });
      }
    });
  }

  @override
  void dispose() {
    _hiddenFocusNode.dispose();
    _controller.dispose();
    _titleController.dispose();
    _scrollController.dispose();
    _editorScrollController.dispose();
    _cursorTimer?.cancel();
    _hideDotTimer?.cancel();
    super.dispose();
  }

  void _saveAndClose() {
    final updatedDoc = Manuscript(
      id: widget.initialDocument.id,
      title: _titleController.text,
      content: _controller.text,
      font: _selectedFont,
      lastModified: DateTime.now(),
      pageCount: _pages.length,
      targetLength: _targetLength,
    );
    int chars = _controller.text.length;
    if (chars > 0) AchievementManager.unlock(context, 'first_notebook');
    if (chars >= 600) AchievementManager.unlock(context, '1min_essay');
    if (DateTime.now().difference(_sessionStartTime).inMinutes >= 60) {
      AchievementManager.unlock(context, 'serious_writer');
    }
    Navigator.pop(context, updatedDoc);
  }

  void _copyToClipboard() {
    String fullText = _titleController.text.isNotEmpty ? "${_titleController.text}\n\n${_controller.text}" : _controller.text;
    Clipboard.setData(ClipboardData(text: fullText));
  }

  void _showFontDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text("글꼴 변경", style: GoogleFonts.nanumMyeongjo(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.text_fields, color: isDark ? Colors.white70 : Colors.black87),
                title: Text("명조체 (기본)", style: GoogleFonts.nanumMyeongjo(color: isDark ? Colors.white : Colors.black87, fontSize: 16)),
                onTap: () { setState(() { _selectedFont = 'myeongjo'; }); Navigator.pop(context); },
              ),
              ListTile(
                leading: Icon(Icons.text_format, color: isDark ? Colors.white70 : Colors.black87),
                title: Text("고딕체", style: GoogleFonts.nanumGothic(color: isDark ? Colors.white : Colors.black87, fontSize: 16)),
                onTap: () { setState(() { _selectedFont = 'gothic'; }); Navigator.pop(context); },
              ),
              ListTile(
                leading: Icon(Icons.draw, color: isDark ? Colors.white70 : Colors.black87),
                title: Text("손글씨 (Nanum Pen Script)", style: GoogleFonts.nanumPenScript(color: isDark ? Colors.white : Colors.black87, fontSize: 22)),
                onTap: () { setState(() { _selectedFont = 'pen'; }); Navigator.pop(context); },
              ),
            ],
          ),
        );
      }
    );
  }

  void _showTargetLengthDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CharacterLimitDialog(
        initialLimit: _targetLength == 0 ? 900 : _targetLength,
        initialEnabled: _targetLength > 0,
      ),
    );

    if (result != null) {
      setState(() {
        _targetLength = result['enabled'] ? result['limit'] as int : 0;
        _updateGrid(); 
      });
    }
  }

  void _exportToPDF() async {
    String fileName = _titleController.text.trim();
    if (fileName.isEmpty) {
      final title = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final TextEditingController tempController = TextEditingController();
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: Text("PDF 내보내기", style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            content: TextField(
              controller: tempController,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: "파일 이름을 입력해주세요", 
                hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey.shade400),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text("취소", style: TextStyle(color: Colors.grey))),
              TextButton(
                onPressed: () => Navigator.pop(ctx, tempController.text.trim()),
                child: const Text("확인", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      );
      if (title == null || title.isEmpty) return; 
      fileName = title;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('PDF 내보내는 중...', textAlign: TextAlign.center, style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold, fontSize: 14)),
      duration: const Duration(milliseconds: 700),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 30, left: 100, right: 100),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      backgroundColor: Colors.black87,
    ));

    final pdf = pw.Document();
    pw.Font font;
    if (_selectedFont == 'pen') {
      font = await PdfGoogleFonts.nanumPenScriptRegular();
    } else if (_selectedFont == 'gothic') {
      font = await PdfGoogleFonts.nanumGothicRegular();
    } else {
      font = await PdfGoogleFonts.nanumMyeongjoRegular();
    }

    final double cellDim = 32.0;
    final double rowGap = 12.0;
    final PdfColor pdfLineColor = PdfColor.fromHex('#FF5252');
    final PdfColor pdfTextColor = PdfColor.fromHex('#212121');

    for (int pageIndex = 0; pageIndex < _pages.length; pageIndex++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context context) {
            List<pw.Widget> rowWidgets = [];
            for (int r = 0; r < 10; r++) {
              List<pw.Widget> cellWidgets = [];
              for (int c = 0; c < 20; c++) {
                int cellIndex = (r * 20) + c;
                String char = _pages[pageIndex][cellIndex];
                cellWidgets.add(pw.Container(
                  width: cellDim, height: cellDim, alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(border: pw.Border(right: c < 19 ? pw.BorderSide(color: pdfLineColor, width: 0.8) : pw.BorderSide.none)),
                  child: char.isNotEmpty ? pw.Text(char, style: pw.TextStyle(font: font, fontSize: _selectedFont == 'pen' ? 18 : 15, color: pdfTextColor)) : null,
                ));
              }
              rowWidgets.add(pw.Container(decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: pdfLineColor, width: 0.8), bottom: pw.BorderSide(color: pdfLineColor, width: 0.8))), child: pw.Row(children: cellWidgets)));
              if (r < 9) rowWidgets.add(pw.SizedBox(height: rowGap));
            }
            final gridWidget = pw.Container(decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: pdfLineColor, width: 0.8), right: pw.BorderSide(color: pdfLineColor, width: 0.8))), child: pw.Column(children: rowWidgets));
            return pw.Center(
              child: pw.Container(
                width: (cellDim * 20) + 80, height: (cellDim * 10) + (rowGap * 9) + 100,
                child: pw.Stack(children: [
                  pw.Positioned(top: 10, right: 40, child: pw.Text("No. ${pageIndex + 1}", style: pw.TextStyle(font: font, fontSize: 14, color: pdfLineColor))),
                  if (pageIndex == 0 && fileName.isNotEmpty) pw.Positioned(top: 25, left: 40, right: 40, child: pw.Center(child: pw.Text(fileName, style: pw.TextStyle(font: font, fontSize: 24, color: pdfTextColor)))),
                  pw.Positioned(top: 70, left: 40, child: gridWidget),
                ])
              )
            );
          },
        ),
      );
    }
    await Printing.sharePdf(bytes: await pdf.save(), filename: '$fileName.pdf');
    if (mounted) AchievementManager.unlock(context, 'real_publisher');
  }

  Widget _buildTooltip({required String message, required Widget child}) {
    return Tooltip(message: message, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF767676), width: 1.0)), textStyle: const TextStyle(color: Colors.black, fontSize: 12), preferBelow: true, verticalOffset: 24, waitDuration: const Duration(milliseconds: 300), child: child);
  }

  void _scrollToCursor() {
    if (!_scrollController.hasClients || _isZoomedOut) return;

    double exactPageHeight = (_cellDim * 10) + (_rowGap * 9) + _marginTop + _marginBottom;
    double titleHeaderHeight = _isSplitMode ? 0.0 : 120.0; 
    
    int row = _activeCellIndex ~/ 20;
    
    double cellTopY = titleHeaderHeight + (_activePageIndex * (exactPageHeight + _pageSpacing)) + _marginTop + (row * (_cellDim + _rowGap));
    double cellBottomY = cellTopY + _cellDim;

    double viewportTop = _scrollController.offset;
    double viewportBottom = viewportTop + _scrollController.position.viewportDimension;

    if (cellBottomY > viewportBottom - 40) {
      _scrollController.animateTo(cellBottomY - _scrollController.position.viewportDimension + 80, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else if (cellTopY < viewportTop + 40) {
      _scrollController.animateTo(cellTopY - 80, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  int _getOffsetFromLocalPosition(Offset localPosition, int pageIndex) {
    double x = localPosition.dx - _marginHorizontal;
    double y = localPosition.dy - _marginTop;
    
    int col = (x / _cellDim).floor().clamp(0, 19);
    int row = (y / (_cellDim + _rowGap)).floor().clamp(0, 9);
    int clickedAbsolute = (pageIndex * 200) + (row * 20) + col;

    int targetOffset = _controller.text.length;
    for (int i = 0; i < _cursorMap.length; i++) {
      int mapAbsolute = _cursorMap[i]["page"]! * 200 + _cursorMap[i]["cell"]!;
      if (mapAbsolute >= clickedAbsolute) {
        targetOffset = i;
        break;
      }
    }
    return targetOffset;
  }

  void _handlePaperTapDown(TapDownDetails details, int pageIndex) {
    int offset = _getOffsetFromLocalPosition(details.localPosition, pageIndex);
    _controller.selection = TextSelection.collapsed(offset: offset);
    _hiddenFocusNode.requestFocus();
  }

  void _handlePaperPanStart(DragStartDetails details, int pageIndex) {
    int offset = _getOffsetFromLocalPosition(details.localPosition, pageIndex);
    _dragBaseOffset = offset;
    _controller.selection = TextSelection.collapsed(offset: offset);
    _hiddenFocusNode.requestFocus();
  }

  void _handlePaperPanUpdate(DragUpdateDetails details, int pageIndex) {
    int offset = _getOffsetFromLocalPosition(details.localPosition, pageIndex);
    if (_dragBaseOffset != -1) {
      _controller.selection = TextSelection(baseOffset: _dragBaseOffset, extentOffset: offset);
    }
  }

  void _updateGrid() {
    String text = _controller.text;
    int cursorPos = _controller.selection.baseOffset;
    if (cursorPos < 0) cursorPos = text.length; 

    _charsWithSpace = text.length;
    _charsWithoutSpace = text.replaceAll(RegExp(r'\s+'), '').length;

    _cursorMap.clear(); 
    List<List<String>> newPages = [];
    List<String> currentPage = List.generate(200, (index) => "");
    
    int cellIndex = 1; 
    bool isHalfFull = false; 
    List<int> newPageBreakIndices = [];

    void triggerPageBreak(int i) {
       newPages.add(currentPage);
       currentPage = List.generate(200, (index) => "");
       cellIndex -= 200;
       if (!newPageBreakIndices.contains(i)) newPageBreakIndices.add(i);
    }

    for (int i = 0; i < text.length; i++) {
      String char = text[i];
      while (cellIndex >= 200) triggerPageBreak(i);
      _cursorMap.add({"page": newPages.length, "cell": cellIndex});
      
      bool isAlphanumeric = RegExp(r'[a-zA-Z0-9]').hasMatch(char);
      
      if (char == '\n') {
        if (isHalfFull) { cellIndex++; isHalfFull = false; while (cellIndex >= 200) triggerPageBreak(i + 1); }
        int currentRow = cellIndex ~/ 20;
        cellIndex = (currentRow + 1) * 20 + 1; 
        while (cellIndex >= 200) triggerPageBreak(i + 1);
        continue;
      }

      if (char == ' ') {
        if (isHalfFull) { cellIndex++; isHalfFull = false; while (cellIndex >= 200) triggerPageBreak(i + 1); }
        if (cellIndex % 20 != 0) { currentPage[cellIndex] = char; cellIndex++; }
        continue;
      }

      if (isAlphanumeric) {
        if (isHalfFull) { currentPage[cellIndex] += char; isHalfFull = false; cellIndex++; } 
        else { currentPage[cellIndex] = char; isHalfFull = true; }
      } else {
        if (isHalfFull) { cellIndex++; isHalfFull = false; while (cellIndex >= 200) triggerPageBreak(i + 1); }
        currentPage[cellIndex] = char;
        cellIndex++;
      }
    }
    
    while (cellIndex >= 200) triggerPageBreak(text.length);
    _cursorMap.add({"page": newPages.length, "cell": cellIndex});
    newPages.add(currentPage);

    while (_pageDates.length < newPages.length) _pageDates.add(DateTime.now());
    if (_pageDates.length > newPages.length) _pageDates = _pageDates.sublist(0, newPages.length);

    _controller.pageBreakIndices = newPageBreakIndices;
    
    _isTyping = true;
    _hideDotTimer?.cancel();
    _hideDotTimer = Timer(const Duration(milliseconds: 300), () { if (mounted) setState(() { _isTyping = false; }); });

    setState(() {
      _pages = newPages;
      if (cursorPos >= 0 && cursorPos < _cursorMap.length) {
        _activePageIndex = _cursorMap[cursorPos]["page"]!;
        _activeCellIndex = _cursorMap[cursorPos]["cell"]!;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) { 
      _scrollToCursor(); 
    });
  }

  void _jumpToPage(int pageIndex) {
    setState(() { _isZoomedOut = false; });
    Future.delayed(const Duration(milliseconds: 60), () {
      if (_scrollController.hasClients) {
        double exactPageHeight = (_cellDim * 10) + (_rowGap * 9) + _marginTop + _marginBottom;
        double targetOffset = pageIndex * (exactPageHeight + _pageSpacing);
        double maxScroll = _scrollController.position.maxScrollExtent;
        if (targetOffset > maxScroll) targetOffset = maxScroll;
        _scrollController.animateTo(targetOffset, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
      }
    });
  }

  Widget _buildTitleHeader(Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 40, bottom: 20),
      alignment: Alignment.center,
      child: IntrinsicWidth(
        child: TextField(
          controller: _titleController,
          textAlign: TextAlign.center,
          style: _selectedFont == 'pen' ? GoogleFonts.nanumPenScript(fontSize: 32, color: textColor) : (_selectedFont == 'gothic' ? GoogleFonts.nanumGothic(fontSize: 26, fontWeight: FontWeight.bold, color: textColor) : GoogleFonts.nanumMyeongjo(fontSize: 26, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 2.0)),
          decoration: InputDecoration(
            hintText: "제목을 입력하세요",
            hintStyle: TextStyle(color: textColor.withOpacity(0.3)),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildPage(int pageIndex, double scale, int themeMode) {
    double paperWidth = ((_cellDim * 20) + (_marginHorizontal * 2)) * scale;
    double paperHeight = ((_cellDim * 10) + (_rowGap * 9) + _marginTop + _marginBottom) * scale;
    DateTime pageDate = _pageDates[pageIndex];
    String dateStr = "${pageDate.year}. ${pageDate.month.toString().padLeft(2, '0')}. ${pageDate.day.toString().padLeft(2, '0')}.";

    Color paperColor, lineColor, textColor, dotColor;
    if (themeMode == 0) { 
      paperColor = Colors.white; lineColor = Colors.redAccent; textColor = const Color(0xFF212121); dotColor = Colors.black87;
    } else if (themeMode == 1) { 
      paperColor = const Color(0xFFBDBDBD); lineColor = const Color(0xFF858585); textColor = const Color(0xFF212121); dotColor = const Color(0xFF555555);
    } else { 
      paperColor = const Color(0xFF1E1E1E); lineColor = const Color(0xFF555555); textColor = Colors.white70; dotColor = Colors.white70;
    }

    int absoluteStart = -1;
    int absoluteEnd = -1;
    if (!_controller.selection.isCollapsed && _controller.selection.start >= 0) {
      if (_controller.selection.start < _cursorMap.length) {
        absoluteStart = _cursorMap[_controller.selection.start]["page"]! * 200 + _cursorMap[_controller.selection.start]["cell"]!;
      }
      if (_controller.selection.end < _cursorMap.length) {
        absoluteEnd = _cursorMap[_controller.selection.end]["page"]! * 200 + _cursorMap[_controller.selection.end]["cell"]!;
      }
    }

    return Container(
      width: paperWidth, height: paperHeight, margin: EdgeInsets.only(bottom: _pageSpacing),
      decoration: BoxDecoration(
        color: paperColor, 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(themeMode == 2 ? 0.3 : 0.05), blurRadius: 10 * scale, offset: Offset(0, 5 * scale))]
      ),
      child: Stack(
        children: [
          Positioned(
            top: (_marginTop - 40) * scale, right: _marginHorizontal * scale,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("No. ${pageIndex + 1}", style: GoogleFonts.nanumMyeongjo(color: lineColor, fontSize: 16 * scale, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
                Text(dateStr, style: GoogleFonts.nanumMyeongjo(color: lineColor.withOpacity(0.6), fontSize: 11 * scale, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          Positioned(
            top: _marginTop * scale, left: _marginHorizontal * scale,
            child: CustomPaint(
              size: Size(_cellDim * 20 * scale, ((_cellDim * 10) + (_rowGap * 9)) * scale), 
              painter: WongojiPainter(
                pageData: _pages[pageIndex], 
                lineColor: lineColor, 
                textColor: textColor, 
                scale: scale, 
                activeCellIndex: _activeCellIndex, 
                isCurrentPage: (pageIndex == _activePageIndex) && !_isZoomedOut, 
                isDotVisible: _isDotVisible, 
                dotX: _dotX, dotY: _dotY, dotColor: dotColor, 
                isZoomedOut: _isZoomedOut, 
                selectedFont: _selectedFont,
                pageIndex: pageIndex,            
                targetLength: _targetLength,
                selectionStart: absoluteStart,
                selectionEnd: absoluteEnd,
              )
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _controller.currentFont = _selectedFont; 
    
    final themeIndex = globalThemeMode.value;
    final isDark = themeIndex == 2;
    final appBarTextColor = Theme.of(context).appBarTheme.iconTheme?.color ?? Colors.black87;
    final sidePanelBg = Theme.of(context).scaffoldBackgroundColor;
    final lineColor = isDark ? const Color(0xFF555555) : Colors.redAccent;
    final textColor = isDark ? Colors.white70 : const Color(0xFF212121);

    Widget editorTextField = TextField(
      focusNode: _hiddenFocusNode,
      controller: _controller,
      scrollController: _isSplitMode ? _editorScrollController : null,
      maxLines: null,
      minLines: _isSplitMode ? null : 1, 
      expands: _isSplitMode, 
      autofocus: true,
      style: _selectedFont == 'pen' ? GoogleFonts.nanumPenScript(fontSize: 23, color: textColor, height: 1.5) : (_selectedFont == 'gothic' ? GoogleFonts.nanumGothic(fontSize: 17, color: textColor, height: 1.8) : GoogleFonts.nanumMyeongjo(fontSize: 18, color: textColor, height: 1.8)),
      decoration: InputDecoration(
        border: InputBorder.none, 
        hintText: _isSplitMode ? _randomHint : "", 
        hintStyle: GoogleFonts.nanumMyeongjo(color: textColor.withOpacity(0.3))
      )
    );

    Widget paperMainArea = Stack(
      children: [
        if (!_isSplitMode)
          Positioned(
            left: -1000, 
            child: Opacity(
              opacity: 0, 
              child: SizedBox(width: 10, child: editorTextField)
            ),
          ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _hiddenFocusNode.requestFocus(),
            child: _isZoomedOut
                ? GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, 
                      crossAxisSpacing: 40, 
                      mainAxisSpacing: 40, 
                      childAspectRatio: 1.45
                    ), 
                    itemCount: _pages.length, 
                    itemBuilder: (context, index) { 
                      return GestureDetector(
                        onTap: () => _jumpToPage(index), 
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.contain, 
                            child: _buildPage(index, 1.0, themeIndex)
                          )
                        )
                      ); 
                    }
                  )
                : ListView.builder(
                    controller: _scrollController, 
                    itemCount: _pages.length + (_isSplitMode ? 0 : 1), 
                    itemBuilder: (context, index) { 
                      if (!_isSplitMode && index == 0) return _buildTitleHeader(textColor);
                      int pageIndex = _isSplitMode ? index : index - 1;
                      return Center(
                        child: GestureDetector(
                          onTapDown: (details) => _handlePaperTapDown(details, pageIndex),
                          onPanStart: (details) => _handlePaperPanStart(details, pageIndex),
                          onPanUpdate: (details) => _handlePaperPanUpdate(details, pageIndex),
                          child: _buildPage(pageIndex, 1.0, themeIndex)
                        ),
                      ); 
                    }
                  ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: appBarTextColor, size: 20), onPressed: _saveAndClose),
        title: Row(
          children: [
            Text("Wongoji ", style: TextStyle(color: appBarTextColor, fontWeight: FontWeight.bold)),
            Text("(공백 포함: $_charsWithSpace | 공백 제외: $_charsWithoutSpace)", style: TextStyle(color: appBarTextColor.withOpacity(0.7), fontSize: 14)),
          ],
        ),
        elevation: 1,
        actions: [
          _buildTooltip(message: "테마 변경", child: IconButton(icon: Icon(themeIndex == 0 ? Icons.light_mode : (themeIndex == 1 ? Icons.monochrome_photos : Icons.dark_mode)), color: appBarTextColor, onPressed: () { globalThemeMode.value = (globalThemeMode.value + 1) % 3; })),
          _buildTooltip(message: _isZoomedOut ? "편집기로 돌아가기" : "모든 페이지 보기", child: IconButton(icon: Icon(_isZoomedOut ? Icons.zoom_in : Icons.grid_view), color: appBarTextColor, onPressed: () { setState(() { _isZoomedOut = !_isZoomedOut; }); })),
          _buildTooltip(
            message: "설정",
            child: PopupMenuButton<String>(
              tooltip: '', icon: Icon(Icons.menu, color: appBarTextColor), color: Theme.of(context).cardColor,
              onSelected: (value) { 
                if (value == 'split') setState(() { _isSplitMode = !_isSplitMode; }); 
                if (value == 'target') _showTargetLengthDialog();
                if (value == 'font') _showFontDialog(isDark); 
                if (value == 'copy') _copyToClipboard(); 
                if (value == 'pdf') _exportToPDF(); 
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'split', child: Row(children: [Icon(Icons.vertical_split, color: appBarTextColor, size: 20), const SizedBox(width: 12), Text(_isSplitMode ? "분할입력창 끄기" : "분할입력창 활성화", style: TextStyle(color: appBarTextColor))])),
                PopupMenuItem(value: 'target', child: Row(children: [Icon(Icons.track_changes, color: appBarTextColor, size: 20), const SizedBox(width: 12), Text("목표 글자수 설정", style: TextStyle(color: appBarTextColor))])),
                PopupMenuItem(value: 'font', child: Row(children: [Icon(Icons.font_download_outlined, color: appBarTextColor, size: 20), const SizedBox(width: 12), Text("글꼴 변경", style: TextStyle(color: appBarTextColor))])),
                PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy, color: appBarTextColor, size: 20), const SizedBox(width: 12), Text("클립보드로 복사", style: TextStyle(color: appBarTextColor))])),
                PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf_outlined, color: appBarTextColor, size: 20), const SizedBox(width: 12), Text("PDF로 내보내기", style: TextStyle(color: appBarTextColor))])),
              ],
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch, 
            children: [
              Expanded(child: paperMainArea),
              if (_isSplitMode && !_isZoomedOut) ...[
                MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) { 
                      setState(() { 
                        _editorWidth -= details.delta.dx; 
                        _editorWidth = _editorWidth.clamp(340.0, max(340.0, constraints.maxWidth - 800.0)); 
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
                            borderRadius: BorderRadius.circular(2.0)
                          )
                        )
                      )
                    )
                  )
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
                        style: _selectedFont == 'pen' ? GoogleFonts.nanumPenScript(fontSize: 28, color: textColor) : (_selectedFont == 'gothic' ? GoogleFonts.nanumGothic(fontSize: 22, fontWeight: FontWeight.bold, color: textColor) : GoogleFonts.nanumMyeongjo(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)), 
                        decoration: InputDecoration(
                          border: InputBorder.none, 
                          hintText: "제목", 
                          hintStyle: GoogleFonts.nanumMyeongjo(color: textColor.withOpacity(0.3), fontWeight: FontWeight.bold)
                        )
                      ),
                      Divider(color: lineColor.withOpacity(0.2)),
                      Expanded(child: editorTextField),
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

class CharacterLimitDialog extends StatefulWidget {
  final int initialLimit;
  final bool initialEnabled;

  const CharacterLimitDialog({
    Key? key,
    this.initialLimit = 900,
    this.initialEnabled = true,
  }) : super(key: key);

  @override
  State<CharacterLimitDialog> createState() => _CharacterLimitDialogState();
}

class _CharacterLimitDialogState extends State<CharacterLimitDialog> {
  late bool _isEnabled;
  late double _currentLimit;

  final Color wongojiRed = const Color(0xFFE57373);
  final Color wongojiDarkRed = const Color(0xFFD32F2F);

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.initialEnabled;
    _currentLimit = widget.initialLimit.toDouble();
  }

  void _addLimit(int amount) {
    setState(() {
      _currentLimit += amount;
      
      _currentLimit = (_currentLimit / 100).round() * 100.0;
      
      if (_currentLimit > 5000) {
        _currentLimit = 5000;
      } else if (_currentLimit < 100) {
        _currentLimit = 100;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wongojiText = isDark ? Colors.white : const Color(0xFF212121);
    final subText = isDark ? Colors.white54 : Colors.grey.shade600;

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      elevation: 24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05), width: 1),
      ),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "목표 글자수",
                  style: GoogleFonts.nanumMyeongjo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: wongojiText,
                  ),
                ),
                Switch(
                  value: _isEnabled,
                  onChanged: (val) => setState(() => _isEnabled = val),
                  activeColor: wongojiRed,
                  activeTrackColor: wongojiRed.withOpacity(0.3),
                  inactiveThumbColor: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  inactiveTrackColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.nanumMyeongjo(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: _isEnabled ? wongojiRed : subText.withOpacity(0.5),
                ),
                child: Text("${_currentLimit.toInt()} 자"),
              ),
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: wongojiRed,
                inactiveTrackColor: wongojiRed.withOpacity(0.15),
                thumbColor: wongojiRed,
                overlayColor: wongojiRed.withOpacity(0.1),
                trackHeight: 4.0,
              ),
              child: Slider(
                value: _currentLimit,
                min: 100,
                max: 5000, 
                onChanged: _isEnabled
                    ? (val) {
                        setState(() {
                          _currentLimit = (val / 100).round() * 100.0;
                        });
                      }
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAddButton(500, isDark),
                const SizedBox(width: 10),
                _buildAddButton(1000, isDark),
                const SizedBox(width: 10),
                _buildAddButton(3000, isDark),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              "공백을 포함한 원고지 칸 수를 기준으로 계산합니다.\n마감 글자수에는 ±10%의 여유가 주어집니다.",
              textAlign: TextAlign.center,
              style: GoogleFonts.nanumGothic(
                fontSize: 12,
                height: 1.6,
                color: subText,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("취소", style: GoogleFonts.nanumGothic(color: subText, fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'enabled': _isEnabled,
                      'limit': _currentLimit.toInt(),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: wongojiRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text("확인", style: GoogleFonts.nanumGothic(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(int amount, bool isDark) {
    return InkWell(
      onTap: _isEnabled ? () => _addLimit(amount) : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _isEnabled ? (isDark ? Colors.white12 : Colors.grey.shade100) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _isEnabled ? (isDark ? Colors.white24 : Colors.grey.shade300) : Colors.transparent,
          ),
        ),
        child: Text(
          "+$amount",
          style: GoogleFonts.nanumGothic(
            color: _isEnabled ? (isDark ? Colors.white70 : Colors.black87) : Colors.grey.shade500, 
            fontWeight: FontWeight.bold, 
            fontSize: 13
          ),
        ),
      ),
    );
  }
}