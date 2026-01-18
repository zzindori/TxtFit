import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 세로 고정 (가로 보기 금지)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const TxtFitApp());
}

class TxtFitApp extends StatelessWidget {
  const TxtFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'txtfit - Knox 텍스트 최적화 유틸리티 (Custom)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0078D4),
      ),
      home: const TxtFitHome(),
    );
  }
}

class TxtFitHome extends StatefulWidget {
  const TxtFitHome({super.key});

  @override
  State<TxtFitHome> createState() => _TxtFitHomeState();
}

class _TxtFitHomeState extends State<TxtFitHome> with TickerProviderStateMixin {
  late final TabController _tabController;

  // --- Split state ---
  final TextEditingController _splitInputCtrl = TextEditingController();
  final TextEditingController _copyPreviewCtrl = TextEditingController();
  int _limit = 3000;
  String _splitInfo = '상태: 대기 중';
  List<String> _splitParts = const [];

  // --- Clean state ---
  final TextEditingController _cleanInputCtrl = TextEditingController();
  final TextEditingController _cleanOutputCtrl = TextEditingController();

  // Scroll controllers
  final ScrollController _splitScrollCtrl = ScrollController();
  final ScrollController _cleanScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _splitInputCtrl.dispose();
    _copyPreviewCtrl.dispose();
    _cleanInputCtrl.dispose();
    _cleanOutputCtrl.dispose();
    _splitScrollCtrl.dispose();
    _cleanScrollCtrl.dispose();
    super.dispose();
  }

  // ---------- Clipboard ----------
  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    setState(() {
      _copyPreviewCtrl.text = text;
    });
  }

  // ---------- Split logic (limit 초과 방지 / [i/n]\n 헤더 포함) ----------
  void _runSplit() {
    final text = _splitInputCtrl.text;
    if (text.isEmpty) {
      setState(() {
        _splitInfo = '상태: 원문이 비어있습니다.';
        _splitParts = const [];
      });
      return;
    }

    final limit = _limit;
    final roughChunk = math.max(1, limit - 50);
    final roughParts = <String>[];
    for (int i = 0; i < text.length; i += roughChunk) {
      roughParts.add(text.substring(i, math.min(i + roughChunk, text.length)));
    }
    int n = roughParts.length;

    List<String> parts = [];
    int i = 0;
    int part = 1;

    while (i < text.length) {
      final header = '[$part/$n]\n';
      final allowed = math.max(1, limit - header.length);
      final end = math.min(i + allowed, text.length);
      parts.add(text.substring(i, end));
      i = end;
      part++;
    }

    // 보정 1회
    if (parts.length != n) {
      n = parts.length;
      final parts2 = <String>[];
      i = 0;
      part = 1;
      while (i < text.length) {
        final header = '[$part/$n]\n';
        final allowed = math.max(1, limit - header.length);
        final end = math.min(i + allowed, text.length);
        parts2.add(text.substring(i, end));
        i = end;
        part++;
      }
      parts = parts2;
    }

    setState(() {
      _splitParts = parts;
      _splitInfo =
          '전체: ${text.length.toString()}자 | 제한: $limit자 | 조각: ${parts.length}개';
    });

    // 결과 영역 맨 위로
    _splitScrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _resetSplit() {
    setState(() {
      _splitInputCtrl.clear();
      _copyPreviewCtrl.clear();
      _splitParts = const [];
      _splitInfo = '상태: 초기화됨';
    });
  }

  // ---------- Clean & Rebuild logic (메타/파트헤더 제거 + 들여쓰기 보존) ----------
  void _runCleanRebuild() {
    final rawText = _cleanInputCtrl.text;
    if (rawText.isEmpty) return;

    final lines = rawText.split('\n');
      final cleaned = <String>[]; // Initialize cleaned list

    final metaPattern =
        RegExp(r'^\[.*?\]\s\d{4}[./-]\d{2}[./-]\d{2}.*'); // probe 기준
    final partHeaderOnlyPattern = RegExp(r'^\[\d+/\d+\]\s*$'); // 단독 라인만

    const keepBlankLines = true;

    for (int i = 0; i < lines.length; i++) {
      final original = lines[i].replaceFirst(RegExp(r'\s+$'), ''); // rstrip
      final probe = original.replaceFirst(RegExp(r'^\s+'), ''); // lstrip

      if (probe.isEmpty) {
        if (keepBlankLines) cleaned.add('');
        continue;
      }

        if (metaPattern.hasMatch(probe)) {
          continue;
        }

        if (partHeaderOnlyPattern.hasMatch(probe)) {
          String mergedResult = '';
          final prevIdx = cleaned.lastIndexWhere((e) => e.trim().isNotEmpty);
          final nextIdx = i + 1;
          final hasPrev = prevIdx != -1;
          final hasNext = nextIdx < lines.length && lines[nextIdx].trim().isNotEmpty;
          if (hasPrev && hasNext) {
            final prev = cleaned[prevIdx];
            final nextLine = lines[nextIdx].replaceFirst(RegExp(r'^\s+'), '');
            mergedResult = prev + nextLine;
            cleaned[prevIdx] = mergedResult;
            i++; // 다음 줄은 이미 붙였으니 건너뜀
          }
          continue;
        }

      cleaned.add(original); // 들여쓰기 보존
    }

    setState(() {
      _cleanOutputCtrl.text = cleaned.join('\n');
    });

    _cleanScrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _copyCleanAll() async {
    await _copyToClipboard(_cleanOutputCtrl.text);
  }

  // ---------- UI helpers ----------
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _primaryButton({
    required String text,
    required VoidCallback onPressed,
    Color? background,
  }) {
    final bg = background ?? const Color(0xFF0078D4);
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onPressed,
        child: Text(text),
      ),
    );
  }

  Widget _secondaryButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onPressed,
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      // ✅ 화면이 키보드 때문에 "리사이즈" 되지 않게 고정
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'T x t F i t',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '문장 분할'),
            Tab(text: '문자열 결합'),
          ],
        ),
      ),
      body: SafeArea(
        // ✅ 키보드가 올라와도 레이아웃 자체는 고정, 대신 아래 패딩으로 가려지는 걸 방지
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSplitTab(),
              _buildCleanTab(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Text(
          '“글자 수 제한? txtfit으로 내 마음대로.”',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildSplitTab() {
    return SingleChildScrollView(
      controller: _splitScrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 분할 설정
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Text('제한 글자 수: ',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      min: 100,
                      max: 10000,
                      divisions: 99,
                      value: _limit.toDouble(),
                      label: '$_limit',
                      onChanged: (v) =>
                          setState(() => _limit = (v ~/ 100) * 100),
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      '$_limit',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Row(
              children: [
                const Text(
                  '1. 원문 입력',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Expanded(child: SizedBox()),
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0078D4),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data != null && data.text != null) {
                        _splitInputCtrl.text = data.text!;
                      }
                    },
                    child: const Text('붙여넣기'),
                  ),
                ),
              ],
            ),
          ),
          TextField(
            controller: _splitInputCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '여기에 긴 텍스트를 붙여넣으세요.',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _primaryButton(
                  text: 'Split 실행',
                  onPressed: _runSplit,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _secondaryButton(
                  text: '초기화',
                  onPressed: _resetSplit,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Text(_splitInfo),

          const SizedBox(height: 14),
          _sectionTitle('2. 분할 결과 (버튼 클릭 시 복사)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _splitParts.isEmpty
                  ? const Text('결과가 없습니다. Split 실행 후 버튼이 생성됩니다.')
                  : Column(
                      children: List.generate(_splitParts.length, (idx) {
                        final partNo = idx + 1;
                        final header = '[$partNo/${_splitParts.length}]\n';
                        final fullText = header + _splitParts[idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            height: 36,
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _copyToClipboard(fullText),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Part $partNo 복사 (${fullText.length}자)',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
            ),
          ),

          const SizedBox(height: 14),
          _sectionTitle('방금 복사된 내용 프리뷰'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _copyPreviewCtrl,
                readOnly: true,
                maxLines: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanTab() {
    return SingleChildScrollView(
      controller: _cleanScrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _sectionTitle('1. 내용 블럭 입력'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: const Size(0, 36),
                  elevation: 0,
                ),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
                    final current = _cleanInputCtrl.text;
                    final toAppend = data.text!;
                    String newText;
                    if (current.trim().isEmpty) {
                      newText = toAppend;
                    } else {
                      newText = "${current.trimRight()}\n$toAppend";
                    }
                    setState(() {
                      _cleanInputCtrl.text = newText;
                      _cleanInputCtrl.selection = TextSelection.collapsed(offset: newText.length);
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('블럭이 붙여넣기 되었습니다.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                child: const Text('블럭 붙여넣기'),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final halfHeight = MediaQuery.of(context).size.height * 0.22;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: halfHeight,
                      child: TextField(
                        controller: _cleanInputCtrl,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          hintText: '블럭을 한 번씩에 붙여넣으세요. (문자열 블럭 입력)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _primaryButton(
                  text: '정제 실행',
                  onPressed: () {
                    _runCleanRebuild();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('정제가 완료되었습니다.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  background: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _secondaryButton(
                  text: '결과 전체 복사',
                  onPressed: () async {
                    await _copyCleanAll();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('결과가 복사되었습니다.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          _sectionTitle('2. 정제 결과'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _cleanOutputCtrl,
                readOnly: true,
                maxLines: 12,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
