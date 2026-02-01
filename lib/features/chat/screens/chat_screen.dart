import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme.dart';

class ChatScreen extends StatefulWidget {
  final String id;
  final String? name;

  const ChatScreen({super.key, required this.id, this.name});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {'text': 'Hi there!', 'isMe': false},
    {'text': 'Hello! How are you?', 'isMe': true},
    {'text': 'I am good. Can you help me with sign language?', 'isMe': false},
  ];

  Future<void> _openSignInput() async {
    final result = await context.push<String>('/sign-input');
    if (result != null && result.isNotEmpty) {
      setState(() {
         // Optionally append or send immediately. Let's append to text field
         // so user can review, or just send it. 
         // Instruction says: "confirm the text and send it back to the chat"
         // I will insert it into the text field for review or send it directly.
         // "Send Button: Icon button to confirm the text and send it back to the chat."
         // Implies "send back to the chat *screen*" or "send as a message"?
         // "Update the local state (Live Caption Box) with the result." -> on Camera screen.
         // On Chat screen, usually "send" means post the message.
         // I will verify standard behavior. Usually it pastes into input or sends immediately.
         // I'll assume it sends immediately as a message for better flow, 
         // or populates the input. Let's populate input for safety.
         _messageController.text = result;
      });
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    setState(() {
      _messages.add({'text': _messageController.text, 'isMe': true});
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name ?? 'Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['isMe'] as bool;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isMe ? AppTheme.primaryColor : Colors.grey[300],
                      borderRadius: BorderRadius.circular(20).copyWith(
                        bottomRight: isMe ? const Radius.circular(0) : null,
                        bottomLeft: !isMe ? const Radius.circular(0) : null,
                      ),
                    ),
                    child: Text(
                      msg['text'] as String,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _openSignInput,
                  icon: const Icon(Icons.cameraswitch_outlined),
                  tooltip: 'Sign with Camera',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                     backgroundColor: AppTheme.primaryColor,
                     foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
