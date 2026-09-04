import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'dart:async';
import 'dart:math';

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

class WongojiEditor extends StatefulWidget {
  const WongojiEditor({Key? key}) : super(key: key);

  @override
  State<WongojiEditor> createState() => _WongojiEditorState();
}

class _WongojiEditorState extends State<WongojiEditor> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _titleController = TextEditingController(); 
  final ScrollController _scrollController = ScrollController();
  
  List<List<String>> _pages = [List.generate(200, (index) => "")];
  List<DateTime> _pageDates = [DateTime.now()]; 
  
  bool _isZoomedOut = false;
  int _themeMode = 0; 

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
  bool _isInternalUpdate = false; // Prevents infinite loops when auto-inserting page breaks

  double _editorWidth = 340.0;

  final double _cellDim = 34.0;
  final double _rowGap = 12.0;
  final double _marginTop = 80.0; 
  final double _marginBottom = 40.0;
  final double _marginHorizontal = 40.0;
  final double _pageSpacing = 30.0;

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
    
    _controller.addListener(_updateGrid);
    
    _titleController.addListener(() {
      setState(() {});
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
            _dotX = 0.8 + (Random().nextDouble() * 0.15); 
          } else {
            _dotX = 0.2 + (Random().nextDouble() * 0.6); 
          }
          _dotY = 0.2 + (Random().nextDouble() * 0.6); 
        });

        Timer(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isDotVisible = false;
            });
          }
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

  void _copyToClipboard() {
    String fullText = _titleController.text.isNotEmpty 
        ? "${_titleController.text}\n\n${_controller.text}" 
        : _controller.text;
    Clipboard.setData(ClipboardData(text: fullText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Text copied to clipboard!'),
        duration: const Duration(seconds: 2),
        backgroundColor: _themeMode == 2 ? Colors.white24 : Colors.black87,
      ),
    );
  }

  void _cycleTheme() {
    setState(() {
      _themeMode = (_themeMode + 1) % 3;
    });
  }

  Widget _buildTooltip({required String message, required Widget child}) {
    return Tooltip(
      message: message,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF767676), width: 1.0),
      ),
      textStyle: const TextStyle(
        color: Colors.black, 
        fontSize: 12,
      ),
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
    List<int> pageSplitIndices = []; // Tracks character indices where pages break

    void checkPageOverflow() {
      while (cellIndex >= 200) {
        newPages.add(currentPage);
        currentPage = List.generate(200, (index) => "");
        cellIndex -= 200;
        pageSplitIndices.add(cursorMap.length);
      }
    }

    for (int i = 0; i < text.length; i++) {
      checkPageOverflow();
      cursorMap.add({"page": newPages.length, "cell": cellIndex});

      String char = text[i];
      bool isAlphanumeric = RegExp(r'[a-zA-Z0-9]').hasMatch(char);
      
      if (char == '\n') {
        if (isHalfFull) {
          cellIndex++;
          isHalfFull = false;
          checkPageOverflow();
        }
        int currentRow = cellIndex ~/ 20;
        cellIndex = (currentRow + 1) * 20 + 1; 
        checkPageOverflow();
        continue;
      }

      if (char == ' ') {
        if (isHalfFull) {
          cellIndex++;
          isHalfFull = false;
          checkPageOverflow();
        }
        if (cellIndex % 20 == 0) {
          continue; 
        }
        currentPage[cellIndex] = char;
        cellIndex++;
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
          checkPageOverflow();
        }
        currentPage[cellIndex] = char;
        cellIndex++;
      }
    }
    
    checkPageOverflow();
    cursorMap.add({"page": newPages.length, "cell": cellIndex});
    newPages.add(currentPage);

    while (_pageDates.length < newPages.length) {
      _pageDates.add(DateTime.now());
    }
    if (_pageDates.length > newPages.length) {
      _pageDates = _pageDates.sublist(0, newPages.length);
    }

    _isTyping = true;
    _hideDotTimer?.cancel();
    _hideDotTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
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
      _isZoomedOut = false; // Instantly exits overview mode
    });
    
    // FIX: Delay ensures the ListView is fully mounted before attempting to animate scroll
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
                  style: GoogleFonts.nanumMyeongjo(
                    fontSize: 22 * scale,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 2.0,
                  ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            message: "Change Theme",
            child: IconButton(
              icon: Icon(
                _themeMode == 0 ? Icons.light_mode : (_themeMode == 1 ? Icons.monochrome_photos : Icons.dark_mode)
              ),
              color: appBarTextColor,
              onPressed: _cycleTheme,
            ),
          ),
          _buildTooltip(
            message: "Copy to Clipboard",
            child: IconButton(
              icon: const Icon(Icons.copy),
              color: appBarTextColor,
              onPressed: _copyToClipboard,
            ),
          ),
          _buildTooltip(
            message: _isZoomedOut ? "Return to Editor" : "View All Pages",
            child: IconButton(
              icon: Icon(_isZoomedOut ? Icons.zoom_in : Icons.grid_view),
              color: appBarTextColor,
              onPressed: () {
                setState(() {
                  _isZoomedOut = !_isZoomedOut;
                });
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
                          // FIX: Removed IgnorePointer so clicks are properly captured
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
                      Text(
                        "Editor",
                        style: GoogleFonts.nanumMyeongjo(
                          color: appBarTextColor.withOpacity(0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _titleController,
                        style: GoogleFonts.nanumMyeongjo(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: "Title...",
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
                          style: GoogleFonts.nanumMyeongjo(
                            color: textColor,
                            fontSize: 18,
                            height: 1.8,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Start drafting here...",
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
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cellDim = 34.0 * scale;
    final double rowGap = 12.0 * scale;

    final paintLine = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0 * scale // RESTORED original crisp line weight
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
          TextSpan span = TextSpan(
            style: GoogleFonts.nanumMyeongjo(
              fontSize: 15 * scale, 
              color: textColor, 
              fontWeight: isZoomedOut ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0,
            ), 
            text: char
          );
          TextPainter tp = TextPainter(
            text: span, 
            textAlign: TextAlign.center, 
            textDirection: TextDirection.ltr
          );
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