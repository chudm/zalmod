// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:zal/Functions/utils.dart';

enum AmdOrNvidia { amd, nvidia }
enum RyzenOrIntel { ryzen, intel }
enum ProgramTimesTimeframe { today, yesterday }
enum StorageType { SSD, HDD }
enum stressTestType { Ram, Cpu, Gpu }
enum SortBy { Name, Memory }
enum DataType { Hardwares, TaskManager }
enum SocketDataType { roomClients, pcData, notifications, drives, directory, file, informationText, fileComplete, gpuProcesses, fpsData, processIcon, runningProcesses }
enum NewNotificationKey { Gpu, Cpu, Ram, Storage, Network }
enum NewNotificationFactorType { Higher, Lower }
enum FileType { file, folder }
enum FileProviderState { downloading, rebuilding, complete }
enum MoveFileType { move, copy }
enum SortFilesBy { nameAscending, nameDescending, sizeAscending, sizeDescending, dateModifiedAscending, dateModifiedDescending, dateCreatedAscending, dateCreatedDescending }

class ComputerAddress {
  String name;
  String ip;
  ComputerAddress({required this.name, required this.ip});
  Map<String, dynamic> toMap() => {'name': name, 'ip': ip};
  factory ComputerAddress.fromMap(Map<String, dynamic> map) => ComputerAddress(name: map['name'] as String, ip: map['ip'] as String);
  String toJson() => json.encode(toMap());
  factory ComputerAddress.fromJson(String source) => ComputerAddress.fromMap(json.decode(source) as Map<String, dynamic>);
}

class ConnectionEstablishment {
  final bool isConnectedToServer;
  final bool isComputerOnlineOnServer;
  final bool isWebrtcConnected;
  final bool hasReceivedData;
  final bool shouldShowConnectedWidget;
  final bool isConnectedToLocalServer;
  ConnectionEstablishment({required this.isConnectedToServer, required this.isComputerOnlineOnServer, required this.isWebrtcConnected, required this.hasReceivedData, required this.shouldShowConnectedWidget, required this.isConnectedToLocalServer});
}

class GpuProcess {
  final int pid;
  final String? icon;
  final int usage;
  final String name;
  GpuProcess({required this.pid, required this.icon, required this.usage, required this.name});
  factory GpuProcess.fromMap(MapEntry<String, dynamic> map) => GpuProcess(pid: map.value['pid']?.toInt() ?? 0, icon: (map.value['icon'] as String?), usage: map.value['usage']?.toInt() ?? 0, name: map.key);
}

class FileData {
  final String name;
  final String? extension;
  final String directory;
  final int size;
  FileType fileType;
  final DateTime dateCreated;
  final DateTime dateModified;
  FileData({required this.name, this.extension, required this.directory, required this.size, required this.fileType, required this.dateCreated, required this.dateModified});
  factory FileData.fromMap(Map<String, dynamic> map) => FileData(name: map['name'] ?? '', extension: map['extension'], directory: map['directory'] ?? '', size: map['size']?.toInt() ?? 0, fileType: FileType.values.byName(map['fileType']), dateCreated: map['dateCreated'] != null ? DateTime.fromMillisecondsSinceEpoch(map['dateCreated']) : DateTime.fromMillisecondsSinceEpoch(0), dateModified: map['dateModified'] != null ? DateTime.fromMillisecondsSinceEpoch(map['dateModified']) : DateTime.fromMillisecondsSinceEpoch(0));
}

class SocketObject {
  late Socket socket;
  Timer? timer;
  SocketObject(String localSocketAddress, {Map<String, dynamic> extraQueries = const {}}) {
    socket = io(localSocketAddress, <String, dynamic>{'transports': ['websocket'], 'query': {...extraQueries, 'EIO': '4'}});
  }
  sendMessage(String to, String data) => socket.emit(to, {'data': data});
}

class SocketData {
  SocketDataType type;
  dynamic data;
  SocketData({required this.data, required this.type});
}

class Cpu {
  String name;
  double? temperature;
  double power;
  SplayTreeMap<String, double> powers = SplayTreeMap();
  SplayTreeMap<String, double?> clocks = SplayTreeMap();
  double load;
  SplayTreeMap<String, double> loads = SplayTreeMap();
  SplayTreeMap<String, double> voltages = SplayTreeMap();
  CpuInfo? cpuInfo;

  Cpu({required this.name, required this.temperature, required this.power, required this.powers, required this.clocks, required this.load, required this.loads, required this.voltages, required this.cpuInfo});

  factory Cpu.fromMap(Map<String, dynamic> map) {
    SplayTreeMap<String, double?> clocks = SplayTreeMap<String, double?>();
    if (map['clocks'] != null) {
      for (final clock in Map<String, dynamic>.from(map['clocks']).entries) {
        // Universal Fix: Handle potential "NaN" strings or nulls from any CPU brand
        var val = clock.value;
        if (val == "NaN" || val == null) {
          clocks[clock.key] = null;
        } else {
          clocks[clock.key] = double.tryParse(val.toString());
        }
      }
    }
    
    // UNIVERSAL FUZZY SEARCH: This works for any CPU brand (Intel/AMD/etc)
    double? temp = map['temperature']?.toDouble();
    if (temp == null || temp <= 0.1 || temp.isNaN || temp.isInfinite) {
      map.forEach((key, value) {
        String k = key.toLowerCase();
        // Scanning for common naming conventions across all monitoring libraries
        if ((k.contains("temp") || k.contains("package") || k.contains("die") || k.contains("tctl") || k.contains("core")) && value is num && value > 5 && value < 120) {
          temp = value.toDouble();
        }
      });
    }
    
    return Cpu(
      name: map['name'] ?? 'Unknown CPU', 
      temperature: (temp == null || temp!.isNaN || temp!.isInfinite) ? 0.0 : temp, 
      power: map['power']?.toDouble() ?? 0.0, 
      powers: SplayTreeMap<String, double>.from(map['powers'] ?? {}), 
      clocks: clocks, 
      load: map['load']?.toDouble() ?? 0.0, 
      loads: SplayTreeMap<String, double>.from(map['loads'] ?? {}), 
      voltages: SplayTreeMap<String, double>.from(map['voltages'] ?? {}), 
      cpuInfo: map['cpuInfo'] != null ? CpuInfo.fromMap(map['cpuInfo']) : null
    );
  }

  factory Cpu.nullData() => Cpu(name: "-1", temperature: -1, power: -1, powers: SplayTreeMap(), clocks: SplayTreeMap(), load: -1, loads: SplayTreeMap(), voltages: SplayTreeMap(), cpuInfo: null);

  CpuCoreInfo getCpuCoreinfo(int index) {
    final clocksList = clocks.entries.toList();
    final loadsList = loads.entries.toList();
    final voltagesList = voltages.entries.toList();
    final powersList = powers.entries.toList();
    return CpuCoreInfo(
      clock: clocksList.length > index ? clocksList[index].value : null,
      load: loadsList.length > index ? loadsList[index].value : null,
      voltage: voltagesList.length > index ? voltagesList[index].value : null,
      power: powersList.length > index ? powersList[index].value : null,
    );
  }
}

class Gpu {
  String name;
  double coreSpeed;
  double memorySpeed;
  double fanSpeedPercentage;
  double corePercentage;
  double power;
  double dedicatedMemoryUsed;
  double temperature;
  double voltage;
  int fps;
  Gpu({required this.name, required this.coreSpeed, required this.memorySpeed, required this.fanSpeedPercentage, required this.corePercentage, required this.power, required this.dedicatedMemoryUsed, required this.temperature, required this.voltage, required this.fps});
  
  factory Gpu.fromMap(Map<String, dynamic> map) {
    // UNIVERSAL FUZZY SEARCH: Works for Nvidia, AMD, and Intel GPUs
    double temp = map['temperature']?.toDouble() ?? 0.0;
    if (temp.isNaN || temp.isInfinite || temp >= 250 || temp <= 0) {
      temp = 0.0;
      map.forEach((key, value) {
        String k = key.toLowerCase();
        if ((k.contains("temp") || k.contains("core") || k.contains("hotspot")) && value is num && value > 5 && value < 120) {
          temp = value.toDouble();
        }
      });
    }
    return Gpu(
      name: map['name'] ?? 'Unknown GPU', 
      coreSpeed: map['coreSpeed']?.toDouble() ?? 0.0, 
      memorySpeed: map['memorySpeed']?.toDouble() ?? 0.0, 
      fanSpeedPercentage: map['fanSpeedPercentage']?.toDouble() ?? 0.0, 
      corePercentage: map['corePercentage']?.toDouble() ?? 0.0, 
      power: map['power']?.toDouble() ?? 0.0, 
      dedicatedMemoryUsed: map['dedicatedMemoryUsed']?.toDouble() ?? 0.0, 
      temperature: temp, 
      voltage: map['voltage']?.toDouble() ?? 0.0, 
      fps: (map['fps'] ?? 0).round()
    );
  }
  factory Gpu.nullData() => Gpu(name: "-1", coreSpeed: -1, memorySpeed: -1, fanSpeedPercentage: -1, corePercentage: -1, power: -1, dedicatedMemoryUsed: -1, temperature: -1, voltage: -1, fps: -1);
}

class ComputerData {
  late Map<String, dynamic> rawData;
  late Ram ram; late Cpu cpu; late Gpu gpu; late List<Storage> storages; late List<Monitor> monitors; late Motherboard motherboard; late Battery battery; late List<NetworkInterface> networkInterfaces;
  List<String>? availableGpus; List<TaskmanagerProcess>? taskmanagerProcesses; NetworkSpeed? networkSpeed; late bool isRunningAsAdminstrator; late Map<String, List<dynamic>> charts;
  
  ComputerData.construct(dynamic data) {
    Map<String, dynamic> parsedData;
    try {
      if (data is String) {
        parsedData = jsonDecode(data);
      } else if (data is Map) {
        parsedData = Map<String, dynamic>.from(data);
      } else {
        parsedData = jsonDecode(data.toString().replaceAll("'", '"'));
      }
    } catch (e) { 
      try {
        parsedData = jsonDecode(data.toString().replaceAll("'", '"'));
      } catch (e2) {
        parsedData = {};
      }
    }
    
    rawData = parsedData;
    charts = parsedData.containsKey("charts") ? Map<String, List<dynamic>>.from(parsedData['charts']) : {};
    final computerData = parsedData['computerData'] ?? parsedData;
    
    // Safety Fallback for "Adminstrator" spelling used in the original app
    isRunningAsAdminstrator = computerData['isAdminstrator'] ?? computerData['isRunningAsAdminstrator'] ?? computerData['isAdmin'] ?? false;
    
    ram = computerData['ramData'] != null ? Ram.fromMap(computerData['ramData']) : Ram.nullData();
    cpu = computerData['cpuData'] != null ? Cpu.fromMap(computerData['cpuData']) : Cpu.nullData();
    gpu = computerData['gpuData'] != null ? Gpu.fromMap(computerData['gpuData']) : Gpu.nullData();
    motherboard = computerData['motherboardData'] != null ? Motherboard.fromMap(computerData['motherboardData']) : Motherboard.nullData();
    battery = computerData['batteryData'] != null ? Battery.fromMap(computerData['batteryData']) : Battery.nullData();
    storages = computerData['storagesData'] != null ? List<Map<String, dynamic>>.from(computerData['storagesData']).map((e) => Storage.fromMap(e)).toList() : [Storage.nullData()];
    monitors = computerData['monitorsData'] != null ? List<Map<String, dynamic>>.from(computerData['monitorsData']).map((e) => Monitor.fromMap(e)).toList() : [Monitor.nullData()];
    
    if (computerData['primaryNetworkSpeed'] != null) networkSpeed = NetworkSpeed.fromMap(computerData["primaryNetworkSpeed"]);
    networkInterfaces = computerData.containsKey("networkInterfaces") ? List<Map<String, dynamic>>.from(computerData['networkInterfaces']).map((e) => NetworkInterface.fromMap(e)).toList() : [];
    if (computerData.containsKey("taskmanagerData") && computerData['taskmanagerData'] != null) taskmanagerProcesses = Map<String, dynamic>.from(computerData['taskmanagerData']).entries.map((e) => TaskmanagerProcess.fromMap(e)).toList();
  }
}

class Storage {
  final int diskNumber; final int totalSize; final int freeSpace; final int temperature; final int readRate; final int writeRate; final String type; final List<Partition>? partitions; final Map<String, dynamic> info; final List<SmartAttribute> smartAttributes;
  Storage({required this.diskNumber, required this.totalSize, required this.freeSpace, required this.temperature, required this.readRate, required this.writeRate, required this.type, required this.partitions, required this.info, required this.smartAttributes});
  String getDisplayName() => "${partitions?.firstOrNull?.label ?? type} | ${totalSize.toSize(decimals: 0)}";
  factory Storage.fromMap(Map<String, dynamic> map) => Storage(diskNumber: map['diskNumber']?.toInt() ?? 0, totalSize: map['totalSize']?.toInt() ?? 0, freeSpace: map['freeSpace']?.toInt() ?? 0, temperature: map['temperature']?.toInt() ?? 0, readRate: map['readRate']?.toInt() ?? 0, writeRate: map['writeRate']?.toInt() ?? 0, type: map['type'] ?? '', partitions: map['partitions'] != null ? List<Partition>.from(map['partitions'].map((x) => Partition.fromMap(x))) : null, info: Map<String, dynamic>.from(map['info'] ?? {}), smartAttributes: map['smartAttributes'] != null ? List<SmartAttribute>.from(map['smartAttributes'].map((e) => SmartAttribute.fromMap(e))) : []);
  factory Storage.nullData() => Storage(diskNumber: -1, totalSize: -1, freeSpace: -1, temperature: -1, readRate: -1, writeRate: -1, type: "HDD", partitions: null, info: {}, smartAttributes: []);
}

class SmartAttribute {
  final String attributeName; final int id; final int? currentValue; final int? worstValue; final int? threshold; final int rawValue;
  SmartAttribute({required this.attributeName, required this.id, this.currentValue, this.worstValue, this.threshold, required this.rawValue});
  factory SmartAttribute.fromMap(Map<String, dynamic> map) => SmartAttribute(attributeName: map['attributeName'] ?? '', id: int.tryParse(map['id'].toString()) ?? 0, currentValue: map['currentValue']?.toInt(), worstValue: map['worstValue']?.toInt(), threshold: map['threshold']?.toInt(), rawValue: map['rawValue']?.toInt() ?? 0);
}

class Ram {
  final double memoryUsed; final double memoryAvailable; final int memoryUsedPercentage; final List<RamPiece> ramPieces;
  Ram({required this.memoryUsed, required this.memoryAvailable, required this.memoryUsedPercentage, required this.ramPieces});
  factory Ram.fromMap(Map<String, dynamic> map) => Ram(memoryUsed: map['memoryUsed']?.toDouble() ?? 0, memoryAvailable: map['memoryAvailable']?.toDouble() ?? 0, memoryUsedPercentage: map['memoryUsedPercentage']?.toInt() ?? 0, ramPieces: map['ramPiecesData'] != null ? List<RamPiece>.from(map['ramPiecesData'].map((x) => RamPiece.fromMap(x))) : []);
  factory Ram.nullData() => Ram(memoryUsed: -1, memoryAvailable: -1, memoryUsedPercentage: -1, ramPieces: []);
}

class NotificationData {
  final NewNotificationKey? key; final NotificationKeyWithUnit? childKey; final NewNotificationFactorType? factorType; final double? factorValue; final int? secondsThreshold; bool suspended;
  NotificationData({this.key, this.childKey, this.factorType, this.factorValue, this.secondsThreshold, this.suspended = false});
  NotificationData copyWith({NewNotificationKey? key, NotificationKeyWithUnit? childKey, NewNotificationFactorType? factorType, double? factorValue, int? secondsThreshold, bool? suspended}) => NotificationData(key: key ?? this.key, childKey: childKey ?? this.childKey, factorType: factorType ?? this.factorType, factorValue: factorValue ?? this.factorValue, secondsThreshold: secondsThreshold ?? this.secondsThreshold, suspended: suspended ?? this.suspended);
  String toJson() => json.encode({'key': key?.index, 'childKey': childKey?.toMap(), 'factorType': factorType?.index, 'factorValue': factorValue, 'secondsThreshold': secondsThreshold, 'suspended': suspended});
  factory NotificationData.fromMap(Map<String, dynamic> map) => NotificationData(key: map['key'] != null ? NewNotificationKey.values[map['key']] : null, childKey: map['childKey'] != null ? NotificationKeyWithUnit.fromMap(map['childKey']) : null, factorType: map['factorType'] != null ? NewNotificationFactorType.values[map['factorType']] : null, factorValue: map['factorValue']?.toDouble(), secondsThreshold: map['secondsThreshold']?.toInt(), suspended: map['suspended'] ?? false);
}

class FpsData {
  List<double> fpsList; double currentFps; double averageFps; double fps01Low; double fps001Low;
  FpsData({required this.fpsList, required this.currentFps, required this.fps01Low, required this.fps001Low, required this.averageFps});
  addFps(double data) => fpsList.add(data);
  calculateFps() { /* Logic handled in provider */ }
}

class FpsRecord {
  FpsData fpsData; String presetName; String presetDuration; String? note;
  FpsRecord({required this.fpsData, required this.presetName, required this.presetDuration, this.note});
}

class ComputerSpecs {
  String motherboardName; String ramSize; String gpuName; String cpuName; List<String> storages; List<String> monitors;
  ComputerSpecs({required this.motherboardName, required this.ramSize, required this.gpuName, required this.cpuName, required this.storages, required this.monitors});
  factory ComputerSpecs.fromComputerData(ComputerData data) => ComputerSpecs(motherboardName: data.motherboard.name, ramSize: "${(data.ram.memoryAvailable + data.ram.memoryUsed).toStringAsFixed(2)}GB", gpuName: data.gpu.name, cpuName: data.cpu.name, storages: data.storages.map((e) => e.type).toList(), monitors: data.monitors.map((e) => e.name).toList());
  String toJson() => json.encode({'motherboardName': motherboardName, 'ramSize': ramSize, 'gpuName': gpuName, 'cpuName': cpuName, 'storages': storages, 'monitors': monitors});
  factory ComputerSpecs.fromJson(String source) { final m = json.decode(source); return ComputerSpecs(motherboardName: m['motherboardName'], ramSize: m['ramSize'], gpuName: m['gpuName'], cpuName: m['cpuName'], storages: List<String>.from(m['storages']), monitors: List<String>.from(m['monitors'])); }
}

class RamPiece { final int capacity; final String manufacturer; final String partNumber; final int clockSpeed; RamPiece({required this.capacity, required this.manufacturer, required this.partNumber, required this.clockSpeed}); factory RamPiece.fromMap(Map<String, dynamic> map) => RamPiece(capacity: map['capacity']?.toInt() ?? 0, manufacturer: map['manufacturer'] ?? '', partNumber: map['partNumber'] ?? '', clockSpeed: map['speed']?.toInt() ?? 0); }
class Partition { final String driveLetter; final String label; final int size; final int freeSpace; Partition({required this.driveLetter, required this.label, required this.size, required this.freeSpace}); factory Partition.fromMap(Map<String, dynamic> map) => Partition(driveLetter: map['driveLetter'] ?? '', label: map['label'] ?? '', size: map['size']?.toInt() ?? 0, freeSpace: map['freeSpace']?.toInt() ?? 0); }
class Motherboard { String name; double temperature; Motherboard({required this.name, required this.temperature}); factory Motherboard.fromMap(Map<String, dynamic> map) => Motherboard(name: map['name'] ?? '', temperature: map['temperature']?.toDouble() ?? 0.0); factory Motherboard.nullData() => Motherboard(name: '-1', temperature: -1); }
class Monitor { String name; bool primary; int height; int width; Monitor({required this.name, required this.primary, required this.height, required this.width}); factory Monitor.fromMap(Map<String, dynamic> map) => Monitor(name: map['name'] ?? '', primary: map['primary'] ?? false, height: map['height']?.toInt() ?? 0, width: map['width']?.toInt() ?? 0); factory Monitor.nullData() => Monitor(name: '-1', primary: false, height: -1, width: -1); }
class Battery { bool isCharging; int batteryPercentage; int lifeRemaining; bool hasBattery; Battery({required this.isCharging, required this.batteryPercentage, required this.lifeRemaining, required this.hasBattery}); factory Battery.fromMap(Map<String, dynamic> map) => Battery(isCharging: map['isCharging'] ?? false, batteryPercentage: map['life']?.toInt() ?? 0, lifeRemaining: map['lifeRemaining']?.toInt() ?? 0, hasBattery: map['hasBattery'] ?? false); factory Battery.nullData() => Battery(isCharging: false, batteryPercentage: 0, lifeRemaining: 0, hasBattery: false); }
class NetworkSpeed { final int download; final int upload; NetworkSpeed({required this.download, required this.upload}); factory NetworkSpeed.fromMap(Map<String, dynamic> map) => NetworkSpeed(download: map['download']?.toInt() ?? 0, upload: map['upload']?.toInt() ?? 0); }
class NetworkInterface { final String name; final String description; final bool isEnabled; final int bytesSent; final int bytesReceived; final bool isPrimary; NetworkInterface({required this.name, required this.description, required this.isEnabled, required this.bytesSent, required this.bytesReceived, required this.isPrimary}); factory NetworkInterface.fromMap(Map<String, dynamic> map) => NetworkInterface(name: map['name'] ?? '', description: map['description'] ?? '', isEnabled: (map['status'] ?? "Down") != "Down", bytesSent: map['bytesSent']?.toInt() ?? 0, bytesReceived: map['bytesReceived']?.toInt() ?? 0, isPrimary: map['isPrimary'] ?? false); }
class TaskmanagerProcess { List<int> pids; String name; double memoryUsage; double cpuPercent; Uint8List? icon; TaskmanagerProcess({required this.pids, required this.name, required this.memoryUsage, required this.cpuPercent, this.icon}); factory TaskmanagerProcess.fromMap(MapEntry<String, dynamic> data) => TaskmanagerProcess(pids: List<int>.from(data.value['pids'] ?? []), name: data.key, memoryUsage: data.value['memoryUsage']?.toDouble() ?? 0.0, cpuPercent: data.value['cpuPercent']?.toDouble() ?? 0.0, icon: data.value['icon'] != null ? base64Decode(data.value['icon']) : null); }
class CpuInfo { String name; String socket; int speed; int cores; int threads; CpuInfo({required this.name, required this.socket, required this.speed, required this.cores, required this.threads}); factory CpuInfo.fromMap(Map<String, dynamic> map) => CpuInfo(name: map['name'] ?? '', socket: map['socket'] ?? '', speed: map['speed']?.toInt() ?? 0, cores: map['cores']?.toInt() ?? 0, threads: map['threads']?.toInt() ?? 0); }
class NotificationKeyWithUnit { String keyName; String unit; String? displayName; NotificationKeyWithUnit({required this.keyName, required this.unit, this.displayName}); factory NotificationKeyWithUnit.fromMap(Map<String, dynamic> map) => NotificationKeyWithUnit(keyName: map['keyName'] ?? '', unit: map['unit'] ?? '', displayName: map['displayName']); Map<String, dynamic> toMap() => {'keyName': keyName, 'unit': unit, 'displayName': displayName}; }
class FpsComputerData { final ComputerData computerData; final Map<String, num> highestValues; FpsComputerData({required this.computerData, required this.highestValues}); }
class CpuCoreInfo { double? clock; double? load; double? voltage; double? power; CpuCoreInfo({this.clock, this.load, this.voltage, this.power}); }
class MoveFileModel { final FileData file; final MoveFileType moveType; MoveFileModel({required this.file, required this.moveType}); }
class NetworkPrefixIsNull implements Exception {}
class ErrorParsingComputerData implements Exception { final String data; final Object error; ErrorParsingComputerData(this.data, this.error); }
