import 'package:flutter/material.dart';
import '../../models/artikel_seni.dart';

class DetailArtikelScreen extends StatelessWidget {
  final ArtikelSeni artikel;

  const DetailArtikelScreen({super.key, required this.artikel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(artikel.judul)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              artikel.gambar,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artikel.judul,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "Asal : ${artikel.asal}",
                    style: const TextStyle(fontSize: 16),
                  ),

                  const SizedBox(height: 20),

                  Text(artikel.isi, style: const TextStyle(fontSize: 16)),

                  const SizedBox(height: 24),

                  const Text(
                    "Pertunjukan Terkait",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),

                  const SizedBox(height: 10),

                  Card(
                    child: ListTile(
                      leading: Icon(Icons.event),
                      title: Text("Festival ${artikel.judul}"),
                      subtitle: Text("Lihat Pertunjukan"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
