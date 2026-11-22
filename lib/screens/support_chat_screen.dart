import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../supabase.dart';
import '../theme/app_theme.dart';

/// شاشة المحادثة — رسائل فورية عبر Supabase Realtime مع تحديث تلقائي احتياطي
class SupportChatScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const SupportChatScreen({super.key, required this.ticket});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  late final String _ticketId;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  Timer? _pollTimer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ticketId = (widget.ticket['id'] ?? widget.ticket['ticket_id'] ?? '').toString();
    _fetchMessages();
    _listen();
  }

  Future<void> _fetchMessages() async {
    if (_ticketId.isEmpty) return;
    try {
      final rows = await supabase
          .from('support_messages')
          .select()
          .eq('ticket_id', _ticketId)
          .order('created_at');
      if (!mounted) return;
      setState(() {
        _messages = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
      _scrollToEnd();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startFallbackPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchMessages();
    });
  }

  void _listen() {
    if (_ticketId.isEmpty) return;
    try {
      _sub = supabase
          .from('support_messages')
          .stream(primaryKey: ['id'])
          .eq('ticket_id', _ticketId)
          .order('created_at')
          .listen(
            (data) {
              if (!mounted) return;
              _pollTimer?.cancel();
              setState(() {
                _messages = List<Map<String, dynamic>>.from(data);
                _loading = false;
              });
              _scrollToEnd();
            },
            onError: (_) {
              // إذا لم يكن Realtime مفعّلاً على الجدول، نعتمد على التحديث الدوري بصمت بدون خطأ مزعج
              _startFallbackPolling();
            },
          );
    } catch (_) {
      _startFallbackPolling();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _ticketId.isEmpty) return;
    final isDev = context.read<AppState>().user?.role == 'developer';
    try {
      await supabase.from('support_messages').insert({
        'ticket_id': _ticketId,
        'sender': isDev ? 'admin' : 'user',
        'body': text,
      });
      _ctrl.clear();
      await _fetchMessages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إرسال الرسالة: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDev = context.watch<AppState>().user?.role == 'developer';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ticket['subject']?.toString() ?? 'الدعم الفني'),
        actions: [
          IconButton(
            onPressed: _fetchMessages,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('اكتب رسالتك وسنرد عليك قريباً'))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final m = _messages[i];
                          final sender = (m['sender'] ?? 'user').toString();
                          final mine = isDev
                              ? (sender == 'admin' || sender == 'developer')
                              : sender == 'user';
                          return Align(
                            alignment: mine
                                ? AlignmentDirectional.centerEnd
                                : AlignmentDirectional.centerStart,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: mine
                                    ? TIColors.orangeDeep
                                    : (isDark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                m['body']?.toString() ?? '',
                                style: TextStyle(
                                  color: mine
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.white
                                          : TIColors.navy),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالة...',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _send,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pollTimer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }
}
