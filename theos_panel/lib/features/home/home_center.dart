import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HomeResumeState { loading, data, empty, error }

final class HomeResumeItem {
  const HomeResumeItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.route,
  });
  final String id;
  final String title;
  final String subtitle;
  final String actionLabel;
  final String? route;
}

final class HomeResumeSnapshot {
  const HomeResumeSnapshot(this.state, {this.items = const [], this.message});
  final HomeResumeState state;
  final List<HomeResumeItem> items;
  final String? message;
}

abstract interface class HomeResumePort {
  HomeResumeSnapshot get snapshot;
  Stream<HomeResumeSnapshot> get changes;
  Future<void> resume(HomeResumeItem item);
}

final homeResumePortProvider = Provider<HomeResumePort>(
  (ref) => const _EmptyHomeResumePort(),
);

final class _EmptyHomeResumePort implements HomeResumePort {
  const _EmptyHomeResumePort();
  @override
  HomeResumeSnapshot get snapshot =>
      const HomeResumeSnapshot(HomeResumeState.empty);
  @override
  Stream<HomeResumeSnapshot> get changes => const Stream.empty();
  @override
  Future<void> resume(HomeResumeItem item) async {}
}

class HomeCenterView extends StatelessWidget {
  const HomeCenterView({required this.port, this.onResume, super.key});
  final HomeResumePort port;
  final Future<void> Function(HomeResumeItem item)? onResume;

  @override
  Widget build(BuildContext context) => StreamBuilder<HomeResumeSnapshot>(
    stream: port.changes,
    initialData: port.snapshot,
    builder: (context, snapshot) {
      final state = snapshot.data ?? port.snapshot;
      return switch (state.state) {
        HomeResumeState.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        HomeResumeState.error => Center(
          child: Text(state.message ?? 'No se pudo cargar el inicio'),
        ),
        HomeResumeState.empty => const Center(
          child: Text('No hay trabajo pendiente'),
        ),
        HomeResumeState.data => _items(context, state.items),
      };
    },
  );

  Widget _items(BuildContext context, List<HomeResumeItem> items) =>
      LayoutBuilder(
        builder: (context, constraints) {
          Widget child(HomeResumeItem item) => Card(
            child: ListTile(
              title: Text(item.title),
              subtitle: Text(item.subtitle),
              trailing: FilledButton(
                onPressed: () =>
                    unawaited(onResume?.call(item) ?? port.resume(item)),
                child: Text(item.actionLabel),
              ),
            ),
          );
          return constraints.maxWidth >= 840
              ? GridView.extent(
                  maxCrossAxisExtent: 420,
                  children: items.map(child).toList(),
                )
              : ListView(children: items.map(child).toList());
        },
      );
}
