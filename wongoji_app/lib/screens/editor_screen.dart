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

class WongojiEditor extends StatefulWidget {
  final Manuscript initialDocument;
  const WongojiEditor({Key? key, required this.initialDocument}) : super(key: key);
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
  String _selectedFont = 'myeongjo'; 
  int _targetLength = 0;

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

  double _editorWidth = 340.0;
  final double _cellDim = 34.0;
  final double _rowGap = 12.0;
  final double _marginTop = 80.0; 
  final double _marginBottom = 40.0;
  final double _marginHorizontal = 40.0;
  final double _pageSpacing = 30.0;

  // Fully Restored Hint Library
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
    
    _titleController.text = widget.initialDocument.title;
    _controller.text = widget.initialDocument.content;
    _selectedFont = widget.initialDocument.font;
    _targetLength = widget.initialDocument.targetLength;

    _controller.addListener(_updateGrid);
    _titleController.addListener(() { setState(() {}); });
    
    WidgetsBinding.instance.addPostFrameCallback((_) { _updateGrid(); });

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
    Navigator.pop(context, updatedDoc);
  }

  void _copyToClipboard() {
    String fullText = _titleController.text.isNotEmpty ? "${_titleController.text}\n\n${_controller.text}" : _controller.text;
    Clipboard.setData(ClipboardData(text: fullText));
  }

  void _showFontDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: appBarBgColor,
          title: Text("글꼴 변경", style: GoogleFonts.nanumMyeongjo(color: appBarTextColor, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.text_fields, color: appBarTextColor),
                title: Text("명조체 (기본)", style: GoogleFonts.nanumMyeongjo(color: textColor, fontSize: 16)),
                onTap: () { setState(() { _selectedFont = 'myeongjo'; }); Navigator.pop(context); },
              ),
              ListTile(
                leading: Icon(Icons.text_format, color: appBarTextColor),
                title: Text("고딕체", style: GoogleFonts.nanumGothic(color: textColor, fontSize: 16)),
                onTap: () { setState(() { _selectedFont = 'gothic'; }); Navigator.pop(context); },
              ),
              ListTile(
                leading: Icon(Icons.draw, color: appBarTextColor),
                title: Text("손글씨 (Nanum Pen Script)", style: GoogleFonts.nanumPenScript(color: textColor, fontSize: 22)),
                onTap: () { setState(() { _selectedFont = 'pen'; }); Navigator.pop(context); },
              ),
            ],
          ),
        );
      }
    );
  }

  void _showTargetLengthDialog() {
    int tempTarget = _targetLength == 0 ? 600 : _targetLength;
    bool isEnabled = _targetLength > 0;
    Color themeBlue = const Color(0xFF5C80D1); 

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: appBarBgColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("글자수 제한 켜기", style: GoogleFonts.nanumMyeongjo(color: appBarTextColor, fontWeight: FontWeight.bold)),
                  Switch(
                    value: isEnabled,
                    activeColor: themeBlue,
                    onChanged: (val) => setDialogState(() => isEnabled = val),
                  )
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      decoration: BoxDecoration(
                        color: isEnabled ? themeBlue : Colors.grey.withOpacity(0.2),
                        border: Border.all(color: Colors.black87, width: 1.0),
                      ),
                      child: Text(
                        isEnabled ? "글자수 제한: $tempTarget 자" : "제한 없음",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nanumGothic(color: isEnabled ? Colors.white : Colors.grey, fontSize: 20)
                      ),
                    ),
                    const SizedBox(height: 32),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: themeBlue,
                        inactiveTrackColor: themeBlue.withOpacity(0.3),
                        thumbColor: themeBlue,
                        trackHeight: 12,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
                      ),
                      child: Slider(
                        value: tempTarget.toDouble(),
                        min: 100,
                        max: 10000,
                        divisions: 99, 
                        label: "$tempTarget 자",
                        onChanged: isEnabled ? (val) => setDialogState(() => tempTarget = val.toInt()) : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildQuickButton("+ 500", () => setDialogState(() => tempTarget = min(10000, tempTarget + 500)), isEnabled, themeBlue),
                        _buildQuickButton("+ 1000", () => setDialogState(() => tempTarget = min(10000, tempTarget + 1000)), isEnabled, themeBlue),
                        _buildQuickButton("+ 3000", () => setDialogState(() => tempTarget = min(10000, tempTarget + 3000)), isEnabled, themeBlue),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text("많은 글쓰기의 글자수제한은 +- 10% 정도의 마진을 둡니다.", style: GoogleFonts.nanumGothic(color: textColor.withOpacity(0.8), fontSize: 13)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소", style: TextStyle(color: Colors.grey))),
                TextButton(
                  onPressed: () {
                    setState(() => _targetLength = isEnabled ? tempTarget : 0);
                    Navigator.pop(context);
                  },
                  child: Text("확인", style: TextStyle(color: themeBlue, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildQuickButton(String label, VoidCallback onTap, bool isEnabled, Color themeBlue) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isEnabled ? themeBlue : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black87, width: 1.0)
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _exportToPDF() async {
    String fileName = _titleController.text.trim();
    if (fileName.isEmpty) fileName = "wongoji_export";
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PDF 내보내는 중...', textAlign: TextAlign.center, style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold, fontSize: 14)),
        duration: const Duration(milliseconds: 700),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 30, left: 100, right: 100),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: _themeMode == 2 ? Colors.white24 : Colors.black87,
      ),
    );

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
                cellWidgets.add(
                  pw.Container(
                    width: cellDim, height: cellDim, alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(border: pw.Border(right: c < 19 ? pw.BorderSide(color: pdfLineColor, width: 0.8) : pw.BorderSide.none)),
                    child: char.isNotEmpty ? pw.Text(char, style: pw.TextStyle(font: font, fontSize: _selectedFont == 'pen' ? 18 : 15, color: pdfTextColor)) : null,
                  )
                );
              }
              rowWidgets.add(
                pw.Container(
                  decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: pdfLineColor, width: 0.8), bottom: pw.BorderSide(color: pdfLineColor, width: 0.8))),
                  child: pw.Row(children: cellWidgets),
                )
              );
              if (r < 9) rowWidgets.add(pw.SizedBox(height: rowGap));
            }
            
            final gridWidget = pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: pdfLineColor, width: 0.8), right: pw.BorderSide(color: pdfLineColor, width: 0.8))),
              child: pw.Column(children: rowWidgets),
            );

            return pw.Center(
              child: pw.Container(
                width: (cellDim * 20) + 80, height: (cellDim * 10) + (rowGap * 9) + 100,
                child: pw.Stack(
                  children: [
                    pw.Positioned(top: 10, right: 40, child: pw.Text("No. ${pageIndex + 1}", style: pw.TextStyle(font: font, fontSize: 14, color: pdfLineColor))),
                    if (pageIndex == 0 && _titleController.text.isNotEmpty)
                      pw.Positioned(top: 25, left: 40, right: 40, child: pw.Center(child: pw.Text(_titleController.text, style: pw.TextStyle(font: font, fontSize: 24, color: pdfTextColor)))),
                    pw.Positioned(top: 70, left: 40, child: gridWidget),
                  ]
                )
              )
            );
          },
        ),
      );
    }
    await Printing.sharePdf(bytes: await pdf.save(), filename: '$fileName.pdf');
  }

  void _cycleTheme() => setState(() { _themeMode = (_themeMode + 1) % 3; });

  Widget _buildTooltip({required String message, required Widget child}) {
    return Tooltip(message: message, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF767676), width: 1.0)), textStyle: const TextStyle(color: Colors.black, fontSize: 12), preferBelow: true, verticalOffset: 24, waitDuration: const Duration(milliseconds: 300), child: child);
  }

  void _updateGrid() {
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
      cursorMap.add({"page": newPages.length, "cell": cellIndex});
      
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
    cursorMap.add({"page": newPages.length, "cell": cellIndex});
    newPages.add(currentPage);

    while (_pageDates.length < newPages.length) _pageDates.add(DateTime.now());
    if (_pageDates.length > newPages.length) _pageDates = _pageDates.sublist(0, newPages.length);

    _controller.pageBreakIndices = newPageBreakIndices;
    _isTyping = true;
    _hideDotTimer?.cancel();
    _hideDotTimer = Timer(const Duration(milliseconds: 300), () { if (mounted) setState(() { _isTyping = false; }); });

    setState(() {
      _pages = newPages;
      if (cursorPos >= 0 && cursorPos < cursorMap.length) {
        _activePageIndex = cursorMap[cursorPos]["page"]!;
        _activeCellIndex = cursorMap[cursorPos]["cell"]!;
      }
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

  Widget _buildPage(int pageIndex, double scale) {
    double paperWidth = ((_cellDim * 20) + (_marginHorizontal * 2)) * scale;
    double paperHeight = ((_cellDim * 10) + (_rowGap * 9) + _marginTop + _marginBottom) * scale;
    DateTime pageDate = _pageDates[pageIndex];
    String dateStr = "${pageDate.year}. ${pageDate.month.toString().padLeft(2, '0')}. ${pageDate.day.toString().padLeft(2, '0')}.";

    return Container(
      width: paperWidth, height: paperHeight, margin: EdgeInsets.only(bottom: _pageSpacing),
      decoration: BoxDecoration(color: paperColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(_themeMode == 2 ? 0.5 : 0.15), blurRadius: 10 * scale, offset: Offset(0, 5 * scale))]),
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
          
          if (_targetLength > 0 && pageIndex == max(0, (_targetLength - 1) ~/ 200))
             Positioned(
               top: (_marginTop - 22) * scale, right: (_marginHorizontal + 70) * scale,
               child: Text(
                 "[ 목표 마감: $_targetLength자 ]",
                 style: GoogleFonts.nanumMyeongjo(color: lineColor.withOpacity(0.8), fontSize: 13 * scale, fontWeight: FontWeight.bold),
               ),
             ),

          if (pageIndex == 0 && _titleController.text.isNotEmpty)
            Positioned(
              top: 25 * scale, left: _marginHorizontal * scale, right: _marginHorizontal * scale,
              child: Center(child: Text(_titleController.text, style: _selectedFont == 'pen' ? GoogleFonts.nanumPenScript(fontSize: 28 * scale, color: textColor) : (_selectedFont == 'gothic' ? GoogleFonts.nanumGothic(fontSize: 22 * scale, fontWeight: FontWeight.bold, color: textColor) : GoogleFonts.nanumMyeongjo(fontSize: 22 * scale, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 2.0)))),
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
                isCurrentPage: (pageIndex == _activePageIndex) && !_isZoomedOut && !_isTyping, 
                isDotVisible: _isDotVisible, 
                dotX: _dotX, 
                dotY: _dotY, 
                dotColor: dotColor, 
                isZoomedOut: _isZoomedOut, 
                selectedFont: _selectedFont,
                pageIndex: pageIndex,           
                targetLength: _targetLength,    
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
    return Scaffold(
      backgroundColor: appBgColor,
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: appBarTextColor, size: 20), onPressed: _saveAndClose),
        title: Row(
          children: [
            Text("Wongoji ", style: TextStyle(color: appBarTextColor, fontWeight: FontWeight.bold)),
            Text("(공백 포함: $_charsWithSpace | 공백 제외: $_charsWithoutSpace)", style: TextStyle(color: appBarTextColor.withOpacity(0.7), fontSize: 14)),
          ],
        ),
        backgroundColor: appBarBgColor,
        elevation: 1,
        actions: [
          _buildTooltip(message: "테마 변경", child: IconButton(icon: Icon(_themeMode == 0 ? Icons.light_mode : (_themeMode == 1 ? Icons.monochrome_photos : Icons.dark_mode)), color: appBarTextColor, onPressed: _cycleTheme)),
          _buildTooltip(message: _isZoomedOut ? "편집기로 돌아가기" : "모든 페이지 보기", child: IconButton(icon: Icon(_isZoomedOut ? Icons.zoom_in : Icons.grid_view), color: appBarTextColor, onPressed: () { setState(() { _isZoomedOut = !_isZoomedOut; }); })),
          _buildTooltip(
            message: "설정",
            child: PopupMenuButton<String>(
              tooltip: '', icon: Icon(Icons.menu, color: appBarTextColor), color: appBarBgColor,
              onSelected: (value) { 
                if (value == 'target') _showTargetLengthDialog(); 
                if (value == 'font') _showFontDialog(); 
                if (value == 'copy') _copyToClipboard(); 
                if (value == 'pdf') _exportToPDF(); 
              },
              itemBuilder: (context) => [
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
              Expanded(
                child: _isZoomedOut
                    ? GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 40, mainAxisSpacing: 40, childAspectRatio: 1.45), itemCount: _pages.length, itemBuilder: (context, index) { return GestureDetector(onTap: () => _jumpToPage(index), child: Center(child: _buildPage(index, 0.65))); })
                    : ListView.builder(controller: _scrollController, padding: const EdgeInsets.only(top: 20), itemCount: _pages.length, itemBuilder: (context, index) { return Center(child: _buildPage(index, 1.0)); }),
              ),
              if (!_isZoomedOut) ...[
                MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) { setState(() { _editorWidth -= details.delta.dx; _editorWidth = _editorWidth.clamp(340.0, max(340.0, constraints.maxWidth - 800.0)); }); },
                    child: Container(width: 12.0, color: sidePanelBg, child: Center(child: Container(width: 2.0, height: 40.0, decoration: BoxDecoration(color: lineColor.withOpacity(0.4), borderRadius: BorderRadius.circular(2.0))))),
                  ),
                ),
                Container(
                  width: _editorWidth, color: sidePanelBg, padding: const EdgeInsets.only(top: 24.0, right: 24.0, bottom: 24.0, left: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(controller: _titleController, style: _selectedFont == 'pen' ? GoogleFonts.nanumPenScript(fontSize: 28, color: textColor) : (_selectedFont == 'gothic' ? GoogleFonts.nanumGothic(fontSize: 22, fontWeight: FontWeight.bold, color: textColor) : GoogleFonts.nanumMyeongjo(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)), decoration: InputDecoration(border: InputBorder.none, hintText: "제목", hintStyle: GoogleFonts.nanumMyeongjo(color: textColor.withOpacity(0.3), fontWeight: FontWeight.bold))),
                      Divider(color: lineColor.withOpacity(0.2)),
                      Expanded(child: TextField(controller: _controller, maxLines: null, minLines: null, expands: true, autofocus: true, style: _selectedFont == 'pen' ? GoogleFonts.nanumPenScript(fontSize: 23, color: textColor, height: 1.5) : (_selectedFont == 'gothic' ? GoogleFonts.nanumGothic(fontSize: 17, color: textColor, height: 1.8) : GoogleFonts.nanumMyeongjo(fontSize: 18, color: textColor, height: 1.8)), decoration: InputDecoration(border: InputBorder.none, hintText: _randomHint, hintStyle: GoogleFonts.nanumMyeongjo(color: textColor.withOpacity(0.3))))),
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