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
    // The decompressed string is the raw JSON from your PC
    final decompressed = decompressGzip(data);
    final computerData = ComputerData.construct(decompressed);
    return computerData;
  }

  @override
  Future<ComputerData> build() async {
    // We wait for the stream from the socket
    final socketData = await ref.watch(_computerDataProvider.future);
    
    late ComputerData data;
    try {
      // FIX: socketData.data IS the string. We remove the extra .data call.
      final rawString = socketData.data.toString();
      data = await _fetchData(rawString);
    } catch (c) {
      print("Parsing Error: $c");
      // Safety: pass the raw string to the error handler
      throw ErrorParsingComputerData(socketData.data.toString(), c);
    }

    if (data.isRunningAsAdminstrator) {
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

final _computerDataProvider = FutureProvider<SocketData>((ref) {
  final sub = ref.listen(socketStreamProvider, (prev, cur) {
    final value = cur.valueOrNull;
    if (value != null) {
      if (value.type == SocketDataType.pcData) {
        ref.state = AsyncData(value);
      }
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
