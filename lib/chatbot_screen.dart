import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'image_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/api_config.dart';

class ChatBotScreen extends StatefulWidget {
  final String? chatId;
  const ChatBotScreen({super.key, this.chatId});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  String? _activeChatId;

  @override
  void initState() {
    super.initState();
    _activeChatId = widget.chatId;
  }

  static String _getCurrentTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  void _scrollToBottom() {
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

  Future<void> _saveMessage(String text, bool isBot) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_activeChatId == null) {
      final chatRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chats')
          .add({
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': text,
        'title': text.length > 30 ? '${text.substring(0, 30)}...' : text,
        'lastTimestamp': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _activeChatId = chatRef.id;
      });

      // Welcome message
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chats')
          .doc(_activeChatId)
          .collection('messages')
          .add({
        'text': 'Salut ! 👋\nJe suis Farmy, votre assistant intelligent. Comment puis-je vous aider aujourd\'hui ?',
        'isBot': true,
        'timestamp': FieldValue.serverTimestamp(),
        'time': _getCurrentTime(),
      });
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .doc(_activeChatId)
        .collection('messages')
        .add({
      'text': text,
      'isBot': isBot,
      'timestamp': FieldValue.serverTimestamp(),
      'time': _getCurrentTime(),
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .doc(_activeChatId)
        .update({
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez vous connecter.")));
      return;
    }

    await _saveMessage(text, false);
    setState(() => _isTyping = true);
    _scrollToBottom();

    try {
      final historySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chats')
          .doc(_activeChatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      List<Map<String, String>> apiMessages = [
        {
          "role": "system",
          "content":
              "Tu es Farmy, un assistant expert en agriculture biologique. Réponds de manière concise."
        }
      ];

      final docs = historySnapshot.docs.reversed.toList();

      for (var doc in docs) {
        apiMessages.add({
          "role": doc['isBot'] ? "assistant" : "user",
          "content": doc['text']
        });
      }

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiConfig.groqApiKey}',
        },
        body: jsonEncode({
          "model": "openai/gpt-oss-20b",
          "messages": apiMessages,
          "temperature": 0.7,
          "max_tokens": 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final botMessage =
            data['choices'][0]['message']['content'];

        await _saveMessage(botMessage.trim(), true);
      } else {
        debugPrint(response.body);
        throw Exception("Erreur Serveur: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur ChatBot: $e")),
      );
    }

    setState(() => _isTyping = false);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF1),
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/bg.png', fit: BoxFit.cover)),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFBFBF1),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30))
                    ),
                    child: Column(
                      children: [
                        Expanded(child: _buildChatList()),
                        if (_isTyping) _buildTypingIndicator(),
                        _buildInputArea(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'chatbot_fab',
        onPressed: () => ImageHelper.showImageSourceDialog(context),
        backgroundColor: const Color(0xFF171717),
        shape: const CircleBorder(),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: const BoxDecoration(color: Color(0xFF00DF00), shape: BoxShape.circle),
          child: const Center(child: Icon(Icons.camera_alt, color: Colors.black, size: 24))
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildRoundButton(Icons.arrow_back, () => Navigator.pop(context)),
          const Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('ChatBot', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
                    SizedBox(width: 4),
                    Icon(Icons.eco, color: Colors.green)
                  ],
                ),
                Text('Votre assistant intelligent', style: TextStyle(fontSize: 12, color: Color(0xFF1C5000))),
              ],
            ),
          ),
          _buildRoundButton(Icons.add, () => setState(() => _activeChatId = null)),
          const SizedBox(width: 8),
          _buildRoundButton(Icons.history, () => _showChatHistory(context)),
        ],
      ),
    );
  }

  Widget _buildRoundButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
        child: Icon(icon, color: const Color(0xFF1C5000), size: 20)
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _buildActionButton(Icons.add, () {}),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey.shade300)
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _handleSend(),
                decoration: const InputDecoration(
                  hintText: 'Posez une question...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10)
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildActionButton(Icons.send, _handleSend),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(color: Color(0xFF1C5000), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20)
      ),
    );
  }

  Widget _buildChatList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _activeChatId == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMessageBubble({
            'isBot': true,
            'text': 'Salut ! 👋\nJe suis Farmy, votre assistant intelligent. Comment puis-je vous aider aujourd\'hui ?',
            'time': _getCurrentTime()
          })
        ]
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chats')
          .doc(_activeChatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Erreur: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        _scrollToBottom();
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) => _buildMessageBubble(docs[index].data() as Map<String, dynamic>)
        );
      },
    );
  }

  void _showChatHistory(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text("Vos Discussions", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1C5000))),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('chats')
                    .orderBy('lastTimestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final chats = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF4C8C2B)),
                        title: Text(chat['title'] ?? "Discussion", maxLines: 1),
                        onTap: () {
                          setState(() => _activeChatId = chats[index].id);
                          Navigator.pop(context);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('chats')
                              .doc(chats[index].id)
                              .delete()
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: const Align(
      alignment: Alignment.centerLeft,
      child: Text("Farmy réfléchit...", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic))
    )
  );

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    bool isBot = msg['isBot'] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isBot) const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.eco, color: Colors.green, size: 20)),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isBot ? Colors.white : const Color(0xFF1C5000),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isBot ? 0 : 20),
                  bottomRight: Radius.circular(isBot ? 20 : 0)
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg['text'] ?? "", style: TextStyle(color: isBot ? Colors.black87 : Colors.white, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(msg['time'] ?? "", style: TextStyle(color: isBot ? Colors.grey : Colors.white70, fontSize: 10)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!isBot) const CircleAvatar(backgroundColor: Color(0xFF1C5000), child: Icon(Icons.person, color: Colors.white, size: 20)),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BottomAppBar(
          height: 80,
          color: const Color(0xFF171717),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_filled, 'Home', false, () => Navigator.pushReplacementNamed(context, '/home')),
              _navItem(Icons.location_on, 'GPS', false, () => Navigator.pushNamed(context, '/gps')),
              const SizedBox(width: 48),
              _navItem(Icons.calendar_month, 'Agenda', false, () => Navigator.pushNamed(context, '/agenda')),
              _navItem(Icons.chat_bubble, 'ChatBot', true, () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? const Color(0xFF00DF00) : Colors.white, size: 24),
          Text(label, style: TextStyle(fontSize: 10, color: active ? const Color(0xFF00DF00) : Colors.white))
        ]
      ),
    );
  }
}
