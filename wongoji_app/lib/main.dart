import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; // The new typography engine!
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
  final ScrollController _scrollController = ScrollController();
  
  List<List<String>> _pages = [List.generate(200, (index) => "")];
  bool _isZoomedOut = false;

  int _charsWithSpace = 0;
  int _charsWithoutSpace = 0;

  // Cursor & Dot Tracking
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
  final double _marginTop = 60.0;
  final double _marginBottom = 40.0;
  final double _marginHorizontal = 40.0;
  final double _pageSpacing = 30.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateGrid);
    
    // Your Custom 500ms / 500ms Blink Timing
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
    _scrollController.dispose();
    _cursorTimer?.cancel();
    _hideDotTimer?.cancel();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied to clipboard!'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.black87,
      ),
    );
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
    int cellIndex = 0;
    bool isHalfFull = false; 

    void checkPageOverflow() {
      if (cellIndex >= 200) {
        newPages.add(currentPage);
        currentPage = List.generate(200, (index) => "");
        cellIndex = 0;
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
        
        if (cellIndex >= 200) {
          newPages.add(currentPage);
          currentPage = List.generate(200, (index) => "");
          cellIndex = 1; 
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
          checkPageOverflow();
        }
        currentPage[cellIndex] = char;
        cellIndex++;
      }
    }
    
    checkPageOverflow();
    cursorMap.add({"page": newPages.length, "cell": cellIndex});
    newPages.add(currentPage);

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
      _activePageIndex = cursorMap[cursorPos]["page"]!;
      _activeCellIndex = cursorMap[cursorPos]["cell"]!;
    });
  }

  void _jumpToPage(int pageIndex) {
    setState(() {
      _isZoomedOut = false;
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        double exactPageHeight = (_cellDim * 10) + (_rowGap * 9) + _marginTop + _marginBottom;
        double offset = 20.0 + (pageIndex * (exactPageHeight + _pageSpacing));
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Widget _buildPage(int pageIndex, double scale) {
    double paperWidth = ((_cellDim * 20) + (_marginHorizontal * 2)) * scale;
    double paperHeight = ((_cellDim * 10) + (_rowGap * 9) + _marginTop + _marginBottom) * scale;

    return Container(
      width: paperWidth,
      height: paperHeight,
      margin: EdgeInsets.only(bottom: _pageSpacing),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10 * scale,
            offset: Offset(0, 5 * scale),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: (_marginTop - 25) * scale,
            right: _marginHorizontal * scale,
            child: Text(
              "No. ${pageIndex + 1}",
              style: GoogleFonts.nanumMyeongjo(
                color: Colors.redAccent,
                fontSize: 16 * scale,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          Positioned(
            top: _marginTop * scale,
            left: _marginHorizontal * scale,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.redAccent, width: 1.0 * scale),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(19, (index) {
                  if (index % 2 == 0) {
                    int rowIndex = index ~/ 2;
                    return SizedBox(
                      height: _cellDim * scale,
                      child: Row(
                        children: List.generate(20, (colIndex) {
                          int cellIndex = (rowIndex * 20) + colIndex;
                          String char = _pages[pageIndex][cellIndex];
                          
                          bool isActiveCell = (pageIndex == _activePageIndex) && (cellIndex == _activeCellIndex);
                          
                          return Container(
                            width: _cellDim * scale,
                            decoration: BoxDecoration(
                              border: Border(
                                right: colIndex < 19 
                                    ? BorderSide(color: Colors.redAccent, width: 1.0 * scale)
                                    : BorderSide.none,
                                bottom: rowIndex < 9
                                    ? BorderSide(color: Colors.redAccent, width: 1.0 * scale)
                                    : BorderSide.none,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Text(
                                    char,
                                    // Applied the Nanum Myeongjo font right here!
                                    style: GoogleFonts.nanumMyeongjo(
                                      fontSize: 15 * scale,
                                      color: Colors.black,
                                      letterSpacing: 0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                // Render the dot only if _isDotVisible is true!
                                if (isActiveCell && !_isZoomedOut && !_isTyping && _isDotVisible)
                                  Align(
                                    alignment: FractionalOffset(_dotX, _dotY),
                                    child: Container(
                                      width: 3.58 * scale, // Scaled down to exactly 80% area
                                      height: 3.58 * scale,
                                      decoration: const BoxDecoration(
                                        color: Colors.black, // Perfect solid black ink
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ),
                    );
                  } else {
                    return Container(
                      height: _rowGap * scale,
                      width: 20 * _cellDim * scale,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.redAccent, width: 1.0 * scale),
                        ),
                      ),
                    );
                  }
                }),
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
      backgroundColor: const Color(0xFFE5E5E5),
      appBar: AppBar(
        title: Row(
          children: [
            const Text("Wongoji ", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            Text(
              "(공백 포함: $_charsWithSpace | 공백 제외: $_charsWithoutSpace)",
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy to Clipboard',
            color: Colors.black,
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: Icon(_isZoomedOut ? Icons.zoom_in : Icons.grid_view),
            color: Colors.black,
            onPressed: () {
              setState(() {
                _isZoomedOut = !_isZoomedOut;
              });
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isZoomedOut
                ? GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, 
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 1.2, 
                    ),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _jumpToPage(index),
                        child: IgnorePointer(
                          child: Center(child: _buildPage(index, 0.23)), 
                        ),
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
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: TextField(
              controller: _controller,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "Type here... (Enter creates a new paragraph)",
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}