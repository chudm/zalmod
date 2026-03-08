import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zal/Functions/local_database_manager.dart';
import 'package:zal/Functions/models.dart';
import 'package:zal/Functions/utils.dart';
import 'package:zal/Screens/MainScreen/main_screen_providers.dart';

class ComputerDataNotifier extends AsyncNotifier<ComputerData> {
  bool isProgramRunningAsAdminstrator = true;
  bool isConnectedToServer = false;
  bool isComputerConnected = false;
  int elpasedTime = 0;

  Future<ComputerData> _fetchData(String data) async {
    // Decompress the raw string from the PC
    final decompressed = decompressGzip(data);
    // Use the fromJson factory we updated in models.dart
    return ComputerData.fromJson(decompressed);
  }

  @override
  Future<ComputerData> build() async {
    // Watch the socket for new data
    final socketData = await ref.watch(_computerDataProvider.future);
    
    late ComputerData data;
    try {
      // THE FIX: Treat socketData directly as the source of truth.
      // We use .toString() to ensure it's a string without calling a missing property.
      final rawString = socketData.toString();
      data = await _fetchData(rawString);
    } catch (c) {
      print("Parsing Error: $c");
      // Safety: pass the string to the error handler
      throw ErrorParsingComputerData(socketData.toString(), c);
    }

    if (data.isRunningAsAdministrator) {
      Future.delayed(const Duration(milliseconds: 100), () {
        ref.read(computerSpecsProvider.notifier).saveSettings(data);
      });
    }
    return data;
  }

  showSnackbarLocal(String text) {
    final context = ref.read(contextProvider);
    if (context != null) showSnackbar(text, context);
  }

  ComputerData attemptToReturnOldData(Exception ifNull) {
    if (state.value != null) {
      return state.value!;
    }
    throw ifNull;
  }
}

final computerDataProvider = AsyncNotifierProvider<ComputerDataNotifier, ComputerData>(() {
  return ComputerDataNotifier();
});

// Internal provider to filter socket stream for actual PC data
final _computerDataProvider = FutureProvider<dynamic>((ref) {
  final sub = ref.listen(socketStreamProvider, (prev, cur) {
    final value = cur.valueOrNull;
    if (value != null) {
      // If the message is identified as PC data, we push it to the listener
      ref.state = AsyncData(value);
    }
  });
  ref.onDispose(() => sub.close());
  return ref.future;
});

class ComputerSpecsNotifier extends AsyncNotifier<ComputerSpecs?> {
  Future<void> saveSettings(ComputerData data) async {
    final computerSpecs = ComputerSpecs.fromComputerData(data);
    state = AsyncData(computerSpecs);
    await LocalDatabaseManager.saveComputerSpecs(computerSpecs);
  }

  Future<ComputerSpecs?> _fetchData() async {
    return await LocalDatabaseManager.loadComputerSpecs();
  }

  @override
  Future<ComputerSpecs?> build() async {
    return _fetchData();
  }
}

final computerSpecsProvider = AsyncNotifierProvider<ComputerSpecsNotifier, ComputerSpecs?>(() {
  return ComputerSpecsNotifier();
});

final timerProvider = StreamProvider<int>((ref) {
  final stopwatch = Stopwatch()..start();
  return Stream.periodic(const Duration(milliseconds: 1000), (count) {
    return stopwatch.elapsed.inSeconds;
  });
});
