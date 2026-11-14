import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../api.dart';

/// Points the app at the GAMEX server (the computer running `npm start`).
Future<void> showServerSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ServerSheet(),
    );

class _ServerSheet extends ConsumerStatefulWidget {
  const _ServerSheet();

  @override
  ConsumerState<_ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends ConsumerState<_ServerSheet> {
  late final _url = TextEditingController(text: ref.read(apiProvider).baseUrl);
  bool _busy = false;
  String? _result;
  bool _ok = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final api = ref.read(apiProvider);
    setState(() => _busy = true);
    await api.setBaseUrl(_url.text);
    _url.text = api.baseUrl;
    try {
      final j = await api.get('/health') as Map;
      _ok = true;
      _result = 'Connected • ${j['listings']} listings on the server';
      // Reload the catalogue from the new server.
      ref.invalidate(apiProvider);
    } catch (e) {
      _ok = false;
      _result = e.toString();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final color = _ok ? const Color(0xFF16A34A) : const Color(0xFFE5283B);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'GAMEX Server',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Seller listings, orders and live reviews come from this server. Default: https://admin.deencircle.online/gamex — for a local test server use its Wi-Fi address, e.g. http://192.168.1.5:8080',
            style: TextStyle(color: Color(0xFF5B6380), height: 1.4),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Server address',
              prefixIcon: Icon(Icons.dns_rounded),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 10),
            Text(
              _result!,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _test,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering_rounded),
            label: const Text('Save & test connection'),
          ),
        ],
      ),
    );
  }
}
