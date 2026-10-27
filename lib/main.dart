import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/design/design_catalog.dart';
import 'core/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const _Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<List<Object>> _load = _resources();
  Future<List<Object>> _resources() => Future.wait<Object>([
    DesignCatalog.load(),
    SharedPreferences.getInstance(),
  ]);
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Object>>(
    future: _load,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return ThinkApp(
          catalog: snapshot.data![0] as DesignCatalog,
          state: AppState(snapshot.data![1] as SharedPreferences),
        );
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: snapshot.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('资源加载失败'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(() => _load = _resources()),
                        child: const Text('重试'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );
}
