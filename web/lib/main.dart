import 'package:flutter/material.dart';
import 'pages/index.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RefractIoTApp());
}

class RefractIoTApp extends StatelessWidget {
  const RefractIoTApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RefractIQ Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DeviceListPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
