import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'dart:async';
import 'dart:math';

// PDF PACKAGES
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(const WongojiApp());
}

// ============================================================================
// DATA MODEL
// ============================================================================
class Manuscript {
  final String id;
  String title;
  String content;
  String font;
  DateTime lastModified;
  int pageCount; 
  DateTime? deletedAt; // NEW: Tracks if and when it was sent to the trash

  Manuscript({
    required this.id,
    this.title = '',
    this.content = '',
    this.font = 'myeongjo',
    required this.lastModified,
    this.pageCount = 1,
    this.deletedAt,
  });
}

class WongojiApp extends StatelessWidget {
  const WongojiApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: NotebookHomeScreen(),
    );
  }
}

// ============================================================================
// NOTEBOOK LANDING PAGE
// ============================================================================
class NotebookHomeScreen extends StatefulWidget {
  const NotebookHomeScreen({Key? key}) : super(key: key);

  @override
  State<NotebookHomeScreen> createState() => _NotebookHomeScreenState();
}

class _NotebookHomeScreenState extends State<NotebookHomeScreen> {
  List<Manuscript> _documents = [];

  @override
  void initState() {
    super.initState();
    _cleanExpiredTrash();
  }

  // Automatically permanently delete items in trash older than 3 days
  void _cleanExpiredTrash() {
    final now = DateTime.now();
    _documents.removeWhere((doc) => doc.deletedAt != null && now.difference(doc.deletedAt!).inDays >= 3);
  }

  List<Manuscript> get _activeDocuments => _documents.where((d) => d.deletedAt == null).toList();

  void _openEditor([Manuscript? doc]) async {
    final isNew = doc == null;
    final targetDoc = doc ?? Manuscript(
      id: DateTime.now().millisecondsSinceEpoch.toString(), 
      lastModified: DateTime.now()
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WongojiEditor(initialDocument: targetDoc),
      ),
    );

    if (result != null && result is Manuscript) {
      setState(() {
        if (isNew) {
          if (result.title.isNotEmpty || result.content.isNotEmpty) {
            _documents.insert(0, result);
          }
        } else {
          final index = _documents.indexWhere((d) => d.id == result.id);
          if (index != -1) {
            _documents[index] = result;
            final updatedDoc = _documents.removeAt(index);
            _documents.insert(0, updatedDoc);
          }
        }
      });
    }
  }

  void _moveToTrash(Manuscript doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text("원고 삭제", style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold)),
        content: Text("이 원고를 휴지통으로 이동하시겠습니까?\n휴지통으로 이동한 원고는 3일 후 영구 삭제됩니다.", style: GoogleFonts.nanumMyeongjo(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                doc.deletedAt = DateTime.now(); // Stamp it for deletion
              });
              Navigator.pop(ctx);
            },
            child: const Text("삭제", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeDocs = _activeDocuments;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), 
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        title: const Text(
          "Wongoji Studio", 
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, letterSpacing: 1.2)
        ),
        actions: [
          // Sidebar menu trigger
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black87),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      endDrawer: _buildSidebarDrawer(context),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "내 원고함",
              style: GoogleFonts.nanumMyeongjo(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int columns = constraints.maxWidth > 1200 ? 5 : (constraints.maxWidth > 800 ? 4 : 2);
                  
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 40,
                      mainAxisSpacing: 40,
                      childAspectRatio: 0.55, 
                    ),
                    itemCount: activeDocs.length + 1, 
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildNewDocumentCard();
                      final doc = activeDocs[index - 1];
                      return DocumentCard(
                        doc: doc,
                        onTap: () => _openEditor(doc),
                        onUpdate: () => setState(() {}), 
                        onDelete: () => _moveToTrash(doc),
                        isTrashMode: false,
                      );
                    },
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- NEW SIDEBAR DRAWER ---
  Widget _buildSidebarDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFF5F5F7)),
            accountName: Text("Wongoji 작가님", style: GoogleFonts.nanumMyeongjo(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: Text("로그인이 필요합니다.", style: GoogleFonts.nanumMyeongjo(color: Colors.grey.shade600)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              child: const Icon(Icons.person, color: Colors.white, size: 40),
            ),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.grey.shade700),
            title: Text("휴지통", style: GoogleFonts.nanumMyeongjo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => TrashBinScreen(
                  documents: _documents,
                  onUpdate: () => setState(() {}),
                ))
              );
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text("Wongoji Studio v0.49", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          )
        ],
      ),
    );
  }

  Widget _buildNewDocumentCard() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1 / 1.414,
              child: GestureDetector(
                onTap: () => _openEditor(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.withOpacity(0.4), width: 2, style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        "새 원고",
                        style: GoogleFonts.nanumMyeongjo(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 24), 
        const SizedBox(height: 4), 
        const SizedBox(height: 16), 
      ],
    );
  }
}

// ============================================================================
// TRASH BIN SCREEN
// ============================================================================
class TrashBinScreen extends StatefulWidget {
  final List<Manuscript> documents;
  final VoidCallback onUpdate;

  const TrashBinScreen({Key? key, required this.documents, required this.onUpdate}) : super(key: key);

  @override
  State<TrashBinScreen> createState() => _TrashBinScreenState();
}

class _TrashBinScreenState extends State<TrashBinScreen> {
  List<Manuscript> get _trashDocuments => widget.documents.where((d) => d.deletedAt != null).toList();

  void _handleTrashAction(Manuscript doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text("원고 관리", style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold)),
        content: Text("이 원고를 어떻게 처리하시겠습니까?", style: GoogleFonts.nanumMyeongjo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              // Delete permanently
              widget.documents.removeWhere((d) => d.id == doc.id);
              widget.onUpdate();
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text("영구 삭제", style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
              // Restore
              doc.deletedAt = null;
              widget.onUpdate();
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text("원고함으로 복구", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = _trashDocuments;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), 
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delete_outline, size: 32, color: Colors.grey.shade700),
                const SizedBox(width: 12),
                Text(
                  "휴지통",
                  style: GoogleFonts.nanumMyeongjo(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "휴지통에 있는 항목은 3일 후 영구 삭제됩니다.",
              style: GoogleFonts.nanumMyeongjo(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 30),
            if (docs.isEmpty)
              Expanded(
                child: Center(
                  child: Text("휴지통이 비어 있습니다.", style: GoogleFonts.nanumMyeongjo(color: Colors.grey.shade400, fontSize: 18)),
                ),
              )
            else
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int columns = constraints.maxWidth > 1200 ? 5 : (constraints.maxWidth > 800 ? 4 : 2);
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 40,
                        mainAxisSpacing: 40,
                        childAspectRatio: 0.55, 
                      ),
                      itemCount: docs.length, 
                      itemBuilder: (context, index) {
                        return DocumentCard(
                          doc: docs[index],
                          onTap: () => _handleTrashAction(docs[index]),
                          onUpdate: () {}, 
                          onDelete: () {}, // Not used in trash
                          isTrashMode: true,
                        );
                      },
                    );
                  }
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DYNAMIC DOCUMENT CARD 
// ============================================================================
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
    required this.isTrashMode,
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
    // If in trash, show days remaining. Otherwise, show date modified.
    String subtitleStr = "";
    if (isTrashMode && doc.deletedAt != null) {
      int daysLeft = 3 - DateTime.now().difference(doc.deletedAt!).inDays;
      if (daysLeft < 0) daysLeft = 0;
      subtitleStr = "영구 삭제까지 ${daysLeft}일 남음";
    } else {
      subtitleStr = "${doc.pageCount}쪽 • ${doc.lastModified.year}.${doc.lastModified.month.toString().padLeft(2, '0')}.${doc.lastModified.day.toString().padLeft(2, '0')}";
    }

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
                child: Stack(
                  children: [
                    Container(
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
                      child: CustomPaint(
                        painter: MinimalCoverPainter(
                          title: displayTitle,
                          fontFamily: doc.font,
                          lineColor: Colors.redAccent.withOpacity(0.6),
                          textColor: const Color(0xFF212121),
                        ),
                      ),
                    ),
                    
                    // The Trash Delete Icon Button Overlay
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
        
        // 3. Subtitle (Page Count / Date / Trash Warning)
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

// ============================================================================
// MINIMAL COVER PAINTER 
// ============================================================================
class MinimalCoverPainter extends CustomPainter {
  final String title;
  final String fontFamily;
  final Color lineColor;
  final Color textColor;

  MinimalCoverPainter({
    required this.title, 
    required this.fontFamily, 
    required this.lineColor, 
    required this.textColor
  });

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
    int cols = (cleanTitle.length / maxRows).ceil();
    if (cols < 1) cols = 1;
    if (cols > 4) cols = 4; 

    double cellDim = 24.0; 
    double gridW = cols * cellDim;
    double gridH = maxRows * cellDim;

    double startX = (size.width - gridW) / 2;
    double startY = (size.height - gridH) / 2;

    final paintLine = Paint()..color = lineColor..strokeWidth = 0.8..style = PaintingStyle.stroke;

    canvas.drawRect(Rect.fromLTWH(startX, startY, gridW, gridH), paintLine);

    for(int i = 1; i < cols; i++) {
       canvas.drawLine(Offset(startX + (i * cellDim), startY), Offset(startX + (i * cellDim), startY + gridH), paintLine);
    }
    
    for(int i = 1; i < maxRows; i++) {
       canvas.drawLine(Offset(startX, startY + (i * cellDim)), Offset(startX + gridW, startY + (i * cellDim)), paintLine);
    }

    for(int c = 0; c < cols; c++) {
       for(int r = 0; r < maxRows; r++) {
          int stringIndex = c * maxRows + r;
          int visualCol = (cols - 1) - c; 
          
          if (stringIndex < cleanTitle.length) {
             String char = cleanTitle[stringIndex];
             
             TextSpan span = TextSpan(style: getTextStyle(fontFamily, cellDim * 0.65, textColor), text: char);
             TextPainter tp = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
             tp.layout();
             
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

// ============================================================================
// NON-DESTRUCTIVE TEXT CONTROLLER
// ============================================================================
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
    
    if (pageBreakIndices.isEmpty) {
      return TextSpan(style: activeStyle, text: text);
    }

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

// ============================================================================
// WONGOJI EDITOR
// ============================================================================
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
    );
    Navigator.pop(context, updatedDoc);
  }

  void _copyToClipboard() {
    String fullText = _titleController.text.isNotEmpty 
        ? "${_titleController.text}\n\n${_controller.text}" 
        : _controller.text;
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
                onTap: () { 
                  setState(() { _selectedFont = 'myeongjo'; }); 
                  Navigator.pop(context); 
                },
              ),
              ListTile(
                leading: Icon(Icons.text_format, color: appBarTextColor),
                title: Text("고딕체", style: GoogleFonts.nanumGothic(color: textColor, fontSize: 16)),
                onTap: () { 
                  setState(() { _selectedFont = 'gothic'; }); 
                  Navigator.pop(context); 
                },
              ),
              ListTile(
                leading: Icon(Icons.draw, color: appBarTextColor),
                title: Text("손글씨 (Nanum Pen Script)", style: GoogleFonts.nanumPenScript(color: textColor, fontSize: 22)),
                onTap: () { 
                  setState(() { _selectedFont = 'pen'; }); 
                  Navigator.pop(context); 
                },
              ),
            ],
          ),
        );
      }
    );
  }

  Future<void> _exportToPDF() async {
    String fileName = _titleController.text.trim();

    if (fileName.isEmpty) {
      final result = await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) {
          String tempName = "";
          return AlertDialog(
            backgroundColor: appBarBgColor,
            title: Text(
              "PDF 저장",
              style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold, color: appBarTextColor),
            ),
            content: TextField(
              autofocus: true,
              style: GoogleFonts.nanumMyeongjo(color: textColor),
              decoration: InputDecoration(
                hintText: "파일 이름을 입력해주세요.",
                hintStyle: GoogleFonts.nanumMyeongjo(color: textColor.withOpacity(0.4)),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.redAccent),
                ),
              ),
              onChanged: (value) {
                tempName = value;
              },
              onSubmitted: (value) {
                Navigator.pop(dialogContext, value);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, null),
                child: const Text("취소", style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, tempName),
                child: const Text("확인", style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          );
        },
      );

      if (result == null || result.trim().isEmpty) return; 
      fileName = result.trim();
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'PDF 내보내는 중...',
          textAlign: TextAlign.center,
          style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold, fontSize: 14),
        ),
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
                    width: cellDim,
                    height: cellDim,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        right: c < 19 ? pw.BorderSide(color: pdfLineColor, width: 0.8) : pw.BorderSide.none,
                      )
                    ),
                    child: char.isNotEmpty ? pw.Text(
                      char, 
                      style: pw.TextStyle(
                        font: font, 
                        fontSize: _selectedFont == 'pen' ? 18 : 15, 
                        color: pdfTextColor
                      )
                    ) : null,
                  )
                );
              }
              
              rowWidgets.add(
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: pdfLineColor, width: 0.8),
                      bottom: pw.BorderSide(color: pdfLineColor, width: 0.8),
                    )
                  ),
                  child: pw.Row(children: cellWidgets),
                )
              );
              
              if (r < 9) {
                rowWidgets.add(pw.SizedBox(height: rowGap));
              }
            }
            
            final gridWidget = pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: pdfLineColor, width: 0.8),
                  right: pw.BorderSide(color: pdfLineColor, width: 0.8),
                )
              ),
              child: pw.Column(children: rowWidgets),
            );

            return pw.Center(
              child: pw.Container(
                width: (cellDim * 20) + 80,
                height: (cellDim * 10) + (rowGap * 9) + 100,
                child: pw.Stack(
                  children: [
                    pw.Positioned(
                      top: 10,
                      right: 40,
                      child: pw.Text(
                        "No. ${pageIndex + 1}",
                        style: pw.TextStyle(
                          font: font, 
                          fontSize: 14, 
                          color: pdfLineColor,
                        ),
                      ),
                    ),
                    if (pageIndex == 0 && _titleController.text.isNotEmpty)
                      pw.Positioned(
                        top: 25,
                        left: 40,
                        right: 40,
                        child: pw.Center(
                          child: pw.Text(
                            _titleController.text,
                            style: pw.TextStyle(
                              font: font, 
                              fontSize: 24, 
                              color: pdfTextColor
                            ),
                          ),
                        ),
                      ),
                    pw.Positioned(
                      top: 70,
                      left: 40,
                      child: gridWidget,
                    ),
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
       if (!newPageBreakIndices.contains(i)) {
         newPageBreakIndices.add(i);
       }
    }

    for (int i = 0; i < text.length; i++) {
      String char = text[i];
      
      while (cellIndex >= 200) triggerPageBreak(i);

      cursorMap.add({"page": newPages.length, "cell": cellIndex});
      
      bool isAlphanumeric = RegExp(r'[a-zA-Z0-9]').hasMatch(char);
      
      if (char == '\n') {
        if (isHalfFull) {
          cellIndex++;
          isHalfFull = false;
          while (cellIndex >= 200) triggerPageBreak(i + 1);
        }
        int currentRow = cellIndex ~/ 20;
        cellIndex = (currentRow + 1) * 20 + 1; 
        while (cellIndex >= 200) triggerPageBreak(i + 1);
        continue;
      }

      if (char == ' ') {
        if (isHalfFull) {
          cellIndex++;
          isHalfFull = false;
          while (cellIndex >= 200) triggerPageBreak(i + 1);
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
          while (cellIndex >= 200) triggerPageBreak(i + 1);
        }
        currentPage[cellIndex] = char;
        cellIndex++;
      }
    }
    
    while (cellIndex >= 200) triggerPageBreak(text.length);
    
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
                selectedFont: _selectedFont, 
              ),
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: appBarTextColor, size: 20),
          onPressed: _saveAndClose,
        ),
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
            message: _isZoomedOut ? "편집기로 돌아가기" : "모든 페이지 보기",
            child: IconButton(
              icon: Icon(_isZoomedOut ? Icons.zoom_in : Icons.grid_view),
              color: appBarTextColor,
              onPressed: () {
                setState(() { _isZoomedOut = !_isZoomedOut; });
              },
            ),
          ),
          _buildTooltip(
            message: "설정",
            child: PopupMenuButton<String>(
              tooltip: '', 
              icon: Icon(Icons.menu, color: appBarTextColor), 
              color: appBarBgColor,
              onSelected: (value) {
                if (value == 'font') _showFontDialog();
                if (value == 'copy') _copyToClipboard();
                if (value == 'pdf') _exportToPDF();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'font',
                  child: Row(
                    children: [
                      Icon(Icons.font_download_outlined, color: appBarTextColor, size: 20),
                      const SizedBox(width: 12),
                      Text("글꼴 변경", style: TextStyle(color: appBarTextColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy, color: appBarTextColor, size: 20),
                      const SizedBox(width: 12),
                      Text("클립보드로 복사", style: TextStyle(color: appBarTextColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_outlined, color: appBarTextColor, size: 20),
                      const SizedBox(width: 12),
                      Text("PDF로 내보내기", style: TextStyle(color: appBarTextColor)),
                    ],
                  ),
                ),
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
            final fallback = const ['Apple SD Gothic Neo', 'Malgun Gothic', 'sans-serif'];
            
            if (selectedFont == 'pen') {
               return GoogleFonts.nanumPenScript(fontSize: fontSize * 1.3, color: textColor, fontWeight: weight).copyWith(fontFamilyFallback: fallback);
            } else if (selectedFont == 'gothic') {
               return GoogleFonts.nanumGothic(fontSize: fontSize, color: textColor, fontWeight: weight).copyWith(fontFamilyFallback: fallback);
            }
            return GoogleFonts.nanumMyeongjo(fontSize: fontSize, color: textColor, fontWeight: weight).copyWith(fontFamilyFallback: fallback);
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