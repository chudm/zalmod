// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:zal/Functions/utils.dart';

// --- ENUMS ---
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

// --- HELPER CLASSES ---
class ComputerAddress {
  String name;
  String ip;
  ComputerAddress({required this.name, required this.ip});
  Map<String, dynamic> toMap() => {'name': name, 'ip': ip};
  factory ComputerAddress.fromMap(Map<String, dynamic> map) => ComputerAddress(name: map['name'] as String, ip: map['ip'] as String);
  String toJson() => json.encode(toMap());
  factory ComputerAddress.fromJson(String source) => ComputerAddress.fromMap(json.decode(source) as Map<String, dynamic>);
  @override
  bool operator ==(covariant ComputerAddress other) => other.name == name && other.ip == ip;
  @override
  int get hashCode => name.hashCode ^ ip.hashCode;
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

// --- CORE HARDWARE MODELS (UPGRADED) ---

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
        clocks[clock.key] = clock.value == "NaN" ? null : clock.value?.toDouble();
      }
    }

    // UPGRADE: Hunt for Zen 5 (9700X) temperature sensors if standard is missing
    double? temp = map['temperature']?.toDouble();
    if (temp == null || temp <= 0.1) {
      map.forEach((key, value) {
        String k = key.toLowerCase();
        if ((k.contains("temp") || k.contains("tctl") || k.contains("tdie")) && value is num && value > 5) {
          temp = value.toDouble();
        }
      });
    }

    final cpu = Cpu(
      name: map['name'] ?? '',
      temperature: temp,
      power: map['power']?.toDouble() ?? 0.0,
      powers: SplayTreeMap<String, double>.from(map['powers'] ?? {}),
      clocks: clocks,
      load: map['load']?.toDouble() ?? 0.0,
      loads: SplayTreeMap<String, double>.from(map['loads'] ?? {}),
      voltages: SplayTreeMap<String, double>.from(map['voltages'] ?? {}),
      cpuInfo: map['cpuInfo'] != null ? CpuInfo.fromMap(map['cpuInfo']) : null,
    );
    return cpu;
  }

  factory Cpu.nullData() => Cpu(name: "-1", temperature: -1, power: -1, powers: SplayTreeMap(), clocks: SplayTreeMap(), load: -1, loads: SplayTreeMap(), voltages: SplayTreeMap(), cpuInfo: null);
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
    // UPGRADE: Fix for the NVIDIA 50-series "255 degree" overflow bug
    double temp = map['temperature']?.toDouble() ?? 0.0;
    if (temp >= 250 || temp <= 0) {
      map.forEach((key, value) {
        if (key.toLowerCase().contains("temp") && value is num && value < 115) {
          temp = value.toDouble();
        }
      });
    }

    return Gpu(
      name: map['name'] ?? '',
      coreSpeed: map['coreSpeed']?.toDouble() ?? 0.0,
      memorySpeed: map['memorySpeed']?.toDouble() ?? 0.0,
      fanSpeedPercentage: map['fanSpeedPercentage']?.toDouble() ?? 0.0,
      corePercentage: map['corePercentage']?.toDouble() ?? 0.0,
      power: map['power']?.toDouble() ?? 0.0,
      dedicatedMemoryUsed: map['dedicatedMemoryUsed']?.toDouble() ?? 0.0,
      temperature: temp,
      voltage: map['voltage']?.toDouble() ?? 0.0,
      fps: (map['fps'] ?? 0).round(),
    );
  }

  factory Gpu.nullData() => Gpu(name: "-1", coreSpeed: -1, memorySpeed: -
