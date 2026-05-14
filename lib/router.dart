import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/home/home_screen.dart';
import 'features/placeholders/placeholder_screen.dart';

/// Typed shell routes — placeholders for Phase 1.
/// Real feature routes are wired in Phase 3 (responsive navigation).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/pos',
        name: 'pos',
        builder: (_, __) => const PlaceholderScreen(title: 'Kasir'),
      ),
      GoRoute(
        path: '/products',
        name: 'products',
        builder: (_, __) => const PlaceholderScreen(title: 'Menu'),
      ),
      GoRoute(
        path: '/inventory',
        name: 'inventory',
        builder: (_, __) => const PlaceholderScreen(title: 'Stok'),
      ),
      GoRoute(
        path: '/transactions',
        name: 'transactions',
        builder: (_, __) => const PlaceholderScreen(title: 'Transaksi'),
      ),
      GoRoute(
        path: '/customers',
        name: 'customers',
        builder: (_, __) => const PlaceholderScreen(title: 'Pelanggan'),
      ),
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (_, __) => const PlaceholderScreen(title: 'Laporan'),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (_, __) => const PlaceholderScreen(title: 'Pengaturan'),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route tidak ditemukan: ${state.uri}')),
    ),
  );
});
