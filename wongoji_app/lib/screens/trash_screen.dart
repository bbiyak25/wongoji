import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/manuscript.dart';
import '../widgets/document_card.dart';

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
              widget.documents.removeWhere((d) => d.id == doc.id);
              widget.onUpdate();
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text("영구 삭제", style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
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
                Text("휴지통", style: GoogleFonts.nanumMyeongjo(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 8),
            Text("휴지통에 있는 항목은 3일 후 영구 삭제됩니다.", style: GoogleFonts.nanumMyeongjo(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 30),
            if (docs.isEmpty)
              Expanded(child: Center(child: Text("휴지통이 비어 있습니다.", style: GoogleFonts.nanumMyeongjo(color: Colors.grey.shade400, fontSize: 18))))
            else
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int columns = constraints.maxWidth > 1200 ? 5 : (constraints.maxWidth > 800 ? 4 : 2);
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns, crossAxisSpacing: 40, mainAxisSpacing: 40, childAspectRatio: 0.55, 
                      ),
                      itemCount: docs.length, 
                      itemBuilder: (context, index) {
                        return DocumentCard(
                          doc: docs[index],
                          onTap: () => _handleTrashAction(docs[index]),
                          onUpdate: () {}, 
                          onDelete: () {}, 
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