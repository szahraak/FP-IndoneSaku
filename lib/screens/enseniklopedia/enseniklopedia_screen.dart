import 'package:flutter/material.dart';

class EnseniklopediaScreen extends StatelessWidget {
  const EnseniklopediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final artikel = [
      {'judul': 'Reog Ponorogo', 'asal': 'Jawa Timur'},
      {'judul': 'Tari Saman', 'asal': 'Aceh'},
      {'judul': 'Wayang Kulit', 'asal': 'Yogyakarta'},
      {'judul': 'Ludruk', 'asal': 'Jawa Timur'},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Enseniklopedia'), centerTitle: true),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: artikel.length,
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book),
              title: Text(artikel[index]['judul']!),
              subtitle: Text(artikel[index]['asal']!),
            ),
          );
        },
      ),
    );
  }
}
