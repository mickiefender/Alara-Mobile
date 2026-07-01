import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:alara/theme.dart';
import 'package:alara/features/communication/communication_screen.dart';

class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: const Text('Messages'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_full_rounded),
            onPressed: () => context.push('/teacher/communication'),
            tooltip: 'Open Communication Hub',
          ),
        ],
      ),
      body: const CommunicationScreen(),
    );
  }
}
