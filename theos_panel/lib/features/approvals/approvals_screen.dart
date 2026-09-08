import 'package:flutter/material.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import 'approval_contracts.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({
    super.key,
    required this.port,
    required this.snapshot,
  });
  final ApprovalPort port;
  final CapabilitySnapshot snapshot;

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  late Future<List<ApprovalRequest>> _pending;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _pending = widget.port.pending();
  }

  void _reload() => setState(() {
    _pending = widget.port.pending();
  });

  Future<void> _resolve(
    ApprovalRequest request,
    ApprovalDecision decision,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await widget.port.resolve(
        request: request,
        decision: decision,
        snapshot: widget.snapshot,
        offline: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
      if (result.accepted) _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fsc(ApprovalRequest request) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await widget.port.performAction(
        request: request,
        action: ApprovalAction.fscInvoiceAndDispatch,
        snapshot: widget.snapshot,
        offline: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Aprobaciones comerciales')),
    body: FutureBuilder<List<ApprovalRequest>>(
      future: _pending,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Semantics(
            liveRegion: true,
            child: Center(
              child: Text(
                'No se pudieron cargar las aprobaciones',
                semanticsLabel: 'Error: no se pudieron cargar las aprobaciones',
              ),
            ),
          );
        }
        final items = snapshot.data ?? const <ApprovalRequest>[];
        if (items.isEmpty) {
          return const Center(child: Text('No hay aprobaciones pendientes'));
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final children = items
                .map((request) => _card(context, request))
                .toList();
            final scale = MediaQuery.textScalerOf(context).scale(1);
            return constraints.maxWidth >= 840
                ? GridView.extent(
                    maxCrossAxisExtent: 560,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: scale >= 1.5 ? 460 : 190,
                    padding: const EdgeInsets.all(16),
                    children: children,
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: children,
                  );
          },
        );
      },
    ),
  );

  Widget _card(BuildContext context, ApprovalRequest request) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pedido ${request.orderDisplayName}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            request.fsc ? 'FSC · contado' : 'Aprobación ${request.terms.name}',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _resolve(request, ApprovalDecision.reject),
                child: const Text('Rechazar'),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _resolve(request, ApprovalDecision.approve),
                child: const Text('Aprobar'),
              ),
              if (request.fsc && request.status == ApprovalStatus.approved)
                TextButton(
                  onPressed: _busy ? null : () => _fsc(request),
                  child: const Text('Preparar FSC'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
