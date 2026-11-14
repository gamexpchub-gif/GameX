import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'theme.dart';
import 'widgets.dart';

/// Lets the seller point the app at the GAMEX server and test it.
Future<void> showServerSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ServerSheet(),
    );

class _ServerSheet extends ConsumerStatefulWidget {
  const _ServerSheet();

  @override
  ConsumerState<_ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends ConsumerState<_ServerSheet> {
  late final _url = TextEditingController(text: ref.read(apiProvider).baseUrl);
  bool _testing = false;
  String? _result;
  bool _ok = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final api = ref.read(apiProvider);
    setState(() {
      _testing = true;
      _result = null;
    });
    await api.setBaseUrl(_url.text);
    _url.text = api.baseUrl;
    try {
      final j = await api.get('/health') as Map;
      _ok = true;
      _result = 'Connected • ${j['listings']} listings on server';
    } catch (e) {
      _ok = false;
      _result = e.toString();
    }
    if (mounted) setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GAMEX server',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Use the address printed when you start the server on your computer (same Wi-Fi), e.g. http://192.168.1.5:8080',
            style: TextStyle(color: C.muted, height: 1.4),
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
            Row(
              children: [
                Icon(
                  _ok ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: _ok ? C.green : C.red,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _result!,
                    style: TextStyle(
                      color: _ok ? C.green : C.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          GradientButton(
            label: 'Save & test connection',
            icon: Icons.wifi_tethering_rounded,
            busy: _testing,
            onPressed: _test,
          ),
        ],
      ),
    );
  }
}
