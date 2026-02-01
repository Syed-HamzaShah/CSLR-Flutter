import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  final List<Map<String, dynamic>> _mockChats = const [
    {
      'id': '1',
      'name': 'Alice Smith',
      'lastMessage': 'See you tomorrow! 👋',
      'time': '10:30 AM',
      'avatarColor': Colors.orange,
    },
    {
      'id': '2',
      'name': 'Bob Johnson',
      'lastMessage': 'Thanks for the help.',
      'time': 'Yesterday',
      'avatarColor': Colors.blue,
    },
    {
      'id': '3',
      'name': 'Charlie Davis',
      'lastMessage': 'Great idea!',
      'time': 'Yesterday',
      'avatarColor': Colors.green,
    },
     {
      'id': '4',
      'name': 'Dana Lee',
      'lastMessage': 'Can you sign that again?',
      'time': 'Mon',
      'avatarColor': Colors.purple,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
      ),
      body: ListView.builder(
        itemCount: _mockChats.length,
        itemBuilder: (context, index) {
          final chat = _mockChats[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: chat['avatarColor'],
              child: Text(
                (chat['name'] as String).substring(0, 1),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              chat['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              chat['lastMessage'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              chat['time'],
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            onTap: () {
              context.push('/chat/${chat['id']}?name=${Uri.encodeComponent(chat['name'])}');
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Start New Chat Feature Implementation Pending')),
          );
        },
        child: const Icon(Icons.chat),
      ),
    );
  }
}
