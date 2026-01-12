import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // (선택) 세로 고정이 필요하면 주석 해제
   await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const TxtFitApp());
}

class TxtFitApp extends StatelessWidget {
  const TxtFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'txtfit - Knox 텍스트 최적화',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Split 탭 변수
  final TextEditingController _splitInputController = TextEditingController();
  final TextEditingController _previewController = TextEditingController();
  int _limitCount = 3000;
  List<String> _chunks = [];
  String _splitStatus = "상태: 대기 중";

  // Clean & Rebuild 탭 변수
  final TextEditingController _cleanInputController = TextEditingController();
  final TextEditingController _cleanOutputController = TextEditingController();

  // --- [공통] 클립보드 복사 ---
  void _copyToClip(String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      setState(() {
        _previewController.text = text;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('클립보드에 복사되었습니다!'),
          duration: Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  // --- [Split] 클립보드 붙여넣기 ---
  Future<void> _pasteToSplitInput() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    if (text.isEmpty) return;

    _splitInputController.text = text;
    _splitInputController.selection = TextSelection.collapsed(offset: text.length);

    setState(() {
      _splitStatus = "클립보드에서 붙여넣기 완료 (${text.length}자)";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('원문 입력칸에 붙여넣었습니다!'),
        duration: Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- [Split] 로직 ---
  void _runSplit() {
    String text = _splitInputController.text;
    if (text.isEmpty) return;

    int chunkSize = _limitCount - 20; // 헤더[n/m] 여유분 제외
    List<String> tempChunks = [];

    for (int i = 0; i < text.length; i += chunkSize) {
      int end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      tempChunks.add(text.substring(i, end));
    }

    setState(() {
      _chunks = tempChunks;
      _splitStatus = "전체: ${text.length}자 | 제한: $_limitCount자 | 조각: ${_chunks.length}개";
    });
  }

  void _resetSplit() {
    setState(() {
      _splitInputController.clear();
      _previewController.clear();
      _chunks = [];
      _splitStatus = "상태: 초기화됨";
    });
  }

  // --- [Clean & Rebuild] 로직 ---
  void _runCleanRebuild() {
    String rawText = _cleanInputController.text;
    if (rawText.isEmpty) return;

    List<String> lines = rawText.split('\n');
    List<String> cleanedLines = [];

    // Knox 특유의 [이름] 날짜 패턴 제거용 정규식
    final metaPattern = RegExp(r'^\[.*?\]\s\d{4}[./-]\d{2}[./-]\d{2}.*');
    final headerPattern = RegExp(r'^\[\d+/\d+\]');

    for (var line in lines) {
      String trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      if (!metaPattern.hasMatch(trimmedLine)) {
        String content = trimmedLine.replaceAll(headerPattern, '').trim();
        if (content.isNotEmpty) cleanedLines.add(content);
      }
    }

    setState(() {
      _cleanOutputController.text = cleanedLines.join('\n');
    });
  }

  void _resetClean() {
    setState(() {
      _cleanInputController.clear();
      _cleanOutputController.clear();
    });
  }

  @override
  void dispose() {
    _splitInputController.dispose();
    _previewController.dispose();
    _cleanInputController.dispose();
    _cleanOutputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        // ✅ 탭/상단 압축용 + 키보드로 인한 과도한 레이아웃 축소 방지에 도움
        resizeToAvoidBottomInset: false,
        
        appBar: AppBar(
          toolbarHeight: 44, // ✅ 타이틀 영역 얇게
          title: const Text(
            'T x t F i t',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(40), // ✅ 탭 영역 얇게
            child: TabBar(
              dividerHeight: 0,
              indicatorWeight: 2,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: const [
                Tab(text: "Split (보내기)"), // ✅ 아이콘 제거
                Tab(text: "Clean (가져오기)"),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildSplitTab(),
            _buildCleanTab(),
          ],
        ),
        bottomNavigationBar: Container(
          height: 22, // ✅ 하단 바 얇게
          alignment: Alignment.center,
          color: Colors.white,
          child: const Text(
            "“글자 수 제한? txtfit으로 내 마음대로.”",
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 10),
          ),
        ),
      ),
    );
  }

  // --- [UI] Split 탭 ---
  Widget _buildSplitTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), // ✅ 전체 패딩 축소
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ 제한 설정(컴팩트)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // ✅ 상하 최소화
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
            ),
            child: Row(
              children: [
                const Text("제한 설정", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _limitCount = (_limitCount > 100) ? _limitCount - 100 : _limitCount),
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  visualDensity: VisualDensity.compact,
                ),
                SizedBox(
                  width: 70,
                  child: Center(
                    child: Text("$_limitCount자", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _limitCount = (_limitCount < 10000) ? _limitCount + 100 : _limitCount),
                  icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ✅ 원문 입력 헤더 + 붙여넣기 버튼 추가
          Row(
            children: [
              const Text(" 1. 원문 입력", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              TextButton.icon(
                onPressed: _pasteToSplitInput,
                icon: const Icon(Icons.content_paste, size: 18),
                label: const Text("붙여넣기", style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Expanded(
            flex: 3,
            child: TextField(
              controller: _splitInputController,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                hintText: "긴 텍스트를 입력하거나, 오른쪽 '붙여넣기' 버튼을 누르세요...",
                fillColor: Colors.white,
                filled: true,
                isDense: true, // ✅ 내부 높이 조금 줄이기
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _runSplit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10), // ✅ 버튼 높이 축소
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text("Split 실행", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _resetSplit,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("초기화", style: TextStyle(fontSize: 13)),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Center(
            child: Text(
              _splitStatus,
              style: const TextStyle(fontSize: 11.5, color: Colors.blueGrey),
            ),
          ),

          const SizedBox(height: 6),

          const Text(" 2. 분할 결과 (클릭 시 복사)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),

          const SizedBox(height: 6),

          Expanded(
            flex: 3,
            child: _chunks.isEmpty
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(child: Text("결과가 여기에 표시됩니다.")),
                  )
                : ListView.builder(
                    itemCount: _chunks.length,
                    itemBuilder: (context, index) {
                      String fullText = "[${index + 1}/${_chunks.length}]\n${_chunks[index]}";
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: Colors.blue, width: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          dense: true, // ✅ 리스트 높이 줄이기
                          visualDensity: VisualDensity.compact,
                          title: Text("Part ${index + 1} (${fullText.length}자)", style: const TextStyle(fontSize: 13)),
                          trailing: const Icon(Icons.copy_all, size: 18, color: Colors.blue),
                          onTap: () => _copyToClip(fullText),
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 6),

          const Text(" 최근 복사 내용 프리뷰", style: TextStyle(fontSize: 11, color: Colors.grey)),

          const SizedBox(height: 6),

          // ✅ 프리뷰 상하 넓게(멀티라인)
          SizedBox(
            height: 90,
            child: TextField(
              controller: _previewController,
              readOnly: true,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                fillColor: Colors.grey[200],
                filled: true,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- [UI] Clean 탭 ---
  Widget _buildCleanTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), // ✅ 전체 패딩 축소
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(" 1. Knox 대화 내용 입력", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),

          const SizedBox(height: 6),

          Expanded(
            child: TextField(
              controller: _cleanInputController,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                fillColor: Colors.white,
                filled: true,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _runCleanRebuild,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10), // ✅ 버튼 높이 축소
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("정제 실행", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _resetClean,
                icon: const Icon(Icons.refresh_rounded),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _copyToClip(_cleanOutputController.text),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("전체 복사", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Text(" 2. 정제 결과 (이름/날짜 제거됨)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),

          const SizedBox(height: 6),

          Expanded(
            child: TextField(
              controller: _cleanOutputController,
              readOnly: true,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                fillColor: Colors.blue[50],
                filled: true,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
