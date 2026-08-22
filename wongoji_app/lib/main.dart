import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
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
    
    _charsWithSpace = text.length;
    _charsWithoutSpace = text.replaceAll(RegExp(r'\s+'), '').length;

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
    
    newPages.add(currentPage);
    bool didAddPage = newPages.length > _pages.length;

    setState(() {
      _pages = newPages;
    });

    if (didAddPage && !_isZoomedOut) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
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
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 16 * scale,
                fontFamily: 'serif',
                fontStyle: FontStyle.italic,
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
                    // TEXT ROW
                    int rowIndex = index ~/ 2;
                    return SizedBox(
                      height: _cellDim * scale,
                      child: Row(
                        children: List.generate(20, (colIndex) {
                          int cellIndex = (rowIndex * 20) + colIndex;
                          String char = _pages[pageIndex][cellIndex];
                          
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
                            child: Center(
                              child: Text(
                                char,
                                style: TextStyle(
                                  fontSize: 15 * scale,
                                  color: Colors.black,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  } else {
                    // GAP ROW
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