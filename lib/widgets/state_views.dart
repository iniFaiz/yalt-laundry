import 'package:flutter/material.dart';

/// Tampilan error dengan tombol "Coba Lagi". Dibungkus ListView agar tetap bisa
/// ditarik untuk refresh saat dipakai di dalam RefreshIndicator.
class ErrorStateView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorStateView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Coba Lagi')),
        ),
      ],
    );
  }
}

/// Tampilan saat data kosong.
class EmptyStateView extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyStateView({super.key, required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }
}
