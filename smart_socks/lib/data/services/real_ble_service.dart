// Real BLE Service using flutter_blue_plus
// Connects to actual smart socks hardware via Bluetooth Low Energy

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/sensor_reading.dart';
import '../../core/constants/sensor_constants.dart';

/// Service for real BLE communication with smart sock device
class RealBleService {
  // Singleton pattern
  static final RealBleService _instance = RealBleService._internal();
  factory RealBleService() => _instance;
  RealBleService._internal();

  // Bluetooth objects
  BluetoothDevice? _device;
  BluetoothCharacteristic? _sensorCharacteristic;
  BluetoothCharacteristic? _batteryCharacteristic;

  // Stream controller for sensor readings
  StreamController<SensorReading>? _streamController;
  StreamSubscription? _notificationSubscription;

  // Connection state
  bool _isConnected = false;
  bool _isStreaming = false;
  String _deviceName = '';
  int _batteryLevel = 0;

  // ============== Getters ==============
  bool get isConnected => _isConnected;
  bool get isStreaming => _isStreaming;
  String get deviceName => _deviceName;
  int get batteryLevel => _batteryLevel;
  Stream<SensorReading>? get sensorStream => _streamController?.stream;

  // ============== Scanning & Connection ==============

  /// Scan for nearby smart socks devices
  Future<List<ScanResult>> scanForDevices({int timeoutSeconds = 10}) async {
    try {
      // BLE is not supported on web platform
      if (kIsWeb) {
        debugPrint('⚠️ Bluetooth not supported on web platform');
        throw Exception('Bluetooth not available on web');
      }

      // Check Bluetooth is on
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        throw Exception('Bluetooth is disabled');
      }

      final results = <ScanResult>[];
      
      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: timeoutSeconds),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      // Listen to scan results
      final subscription = FlutterBluePlus.scanResults.listen((scanResults) {
        for (ScanResult result in scanResults) {
          // Filter for NeuroSock devices
          if (result.device.platformName.startsWith(SensorConstants.bleDeviceNamePrefix)) {
            if (!results.any((r) => r.device.remoteId == result.device.remoteId)) {
              results.add(result);
            }
          }
        }
      });

      // Wait for scan to complete
      await Future.delayed(Duration(seconds: timeoutSeconds));
      await FlutterBluePlus.stopScan();
      await subscription.cancel();

      return results;
    } catch (e) {
      await FlutterBluePlus.stopScan();
      throw Exception('Scan failed: $e');
    }
  }

  /// Connect to a specific device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // BLE is not supported on web platform
      if (kIsWeb) {
        debugPrint('⚠️ Bluetooth not supported on web platform');
        throw Exception('Bluetooth not available on web');
      }

      _device = device;
      _deviceName = device.platformName;

      // Connect with timeout
      await device.connect(timeout: const Duration(seconds: 10));
      _isConnected = true;

      // Discover services
      await _discoverServices();

      return true;
    } catch (e) {
      _isConnected = false;
      throw Exception('Connection failed: $e');
    }
  }

  /// Discover services and characteristics
  Future<void> _discoverServices() async {
    try {
      if (_device == null) throw Exception('Device not set');

      final services = await _device!.discoverServices();

      for (var service in services) {
        // Look for sensor service (using standard Heart Rate service UUID as placeholder)
        if (service.uuid.toString() == SensorConstants.bleServiceUuid ||
            service.uuid.toString().contains('180D')) {
          // Find sensor data characteristic
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == SensorConstants.bleSensorCharUuid ||
                characteristic.uuid.toString().contains('2A37')) {
              _sensorCharacteristic = characteristic;
            }
            // Find battery characteristic
            if (characteristic.uuid.toString() == SensorConstants.bleBatteryCharUuid ||
                characteristic.uuid.toString().contains('2A19')) {
              _batteryCharacteristic = characteristic;
              await _readBatteryLevel();
            }
          }
        }
      }

      if (_sensorCharacteristic == null) {
        throw Exception('Sensor characteristic not found');
      }
    } catch (e) {
      _isConnected = false;
      throw Exception('Service discovery failed: $e');
    }
  }

  /// Read battery level once
  Future<void> _readBatteryLevel() async {
    try {
      if (_batteryCharacteristic == null) return;

      final value = await _batteryCharacteristic!.read();
      if (value.isNotEmpty) {
        _batteryLevel = value[0];
      }
    } catch (e) {
      debugPrint('Battery read error: $e');
    }
  }

  /// Generic debug print function
  void debugPrint(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(message);
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    try {
      if (kIsWeb) {
        return; // No-op on web
      }
      await stopStreaming();
      await _device?.disconnect();
      _isConnected = false;
      _device = null;
      _sensorCharacteristic = null;
      _batteryCharacteristic = null;
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
  }

  // ============== Streaming ==============

  /// Start streaming sensor data from device
  Future<void> startStreaming() async {
    try {
      // BLE is not supported on web platform
      if (kIsWeb) {
        debugPrint('⚠️ Bluetooth not supported on web platform. Use Firestore data.');
        throw Exception('Bluetooth not available on web');
      }

      if (!_isConnected || _sensorCharacteristic == null) {
        throw Exception('Device not connected or characteristic not found');
      }

      _streamController = StreamController<SensorReading>.broadcast();
      _isStreaming = true;

      // Set up notifications
      await _sensorCharacteristic!.setNotifyValue(true);

      _notificationSubscription = _sensorCharacteristic!.lastValueStream.listen(
        (value) async {
          try {
            final reading = _parseBleSensorData(value);
            if (reading != null) {
              _streamController?.add(reading);
            }
          } catch (e) {
            debugPrint('Parse error: $e');
          }
        },
        onError: (e) {
          debugPrint('Stream error: $e');
          _streamController?.addError(e);
        },
      );
    } catch (e) {
      _isStreaming = false;
      throw Exception('Failed to start streaming: $e');
    }
  }

  /// Stop streaming
  Future<void> stopStreaming() async {
    try {
      if (kIsWeb) {
        return; // No-op on web
      }
      _isStreaming = false;
      await _notificationSubscription?.cancel();
      await _sensorCharacteristic?.setNotifyValue(false);
      await _streamController?.close();
      _streamController = null;
    } catch (e) {
      debugPrint('Stop streaming error: $e');
    }
  }

  // ============== Data Parsing ==============

  /// Parse raw BLE data into SensorReading
  /// Expected format (example): 
  /// Bytes 0-3: Temperatures (4 sensors) x 1 degree each
  /// Bytes 4-7: Pressures (4 sensors) x 1 kPa each
  /// Bytes 8-9: SpO2 (uint16)
  /// Bytes 10-11: Heart Rate (uint16)
  /// Bytes 12-13: Step count (uint16)
  /// Bytes 14: Activity type
  /// Bytes 15: Battery level
  SensorReading? _parseBleSensorData(List<int> data) {
    try {
      if (data.length < 16) {
        debugPrint('Invalid data length: ${data.length}');
        return null;
      }

      // Parse temperatures (indices 0-3)
      final temperatures = <double>[];
      for (int i = 0; i < 4; i++) {
        temperatures.add(25.0 + (data[i] - 128) / 2.0); // -40°C to +120°C range
      }

      // Parse pressures (indices 4-7)
      final pressures = <double>[];
      for (int i = 0; i < 4; i++) {
        pressures.add(data[4 + i] * 0.3); // 0-77 kPa range
      }

      // Parse SpO2 (indices 8-9)
      final spO2 = ((data[8] << 8) | data[9]) / 100.0;

      // Parse heart rate (indices 10-11)
      final heartRate = (data[10] << 8) | data[11];

      // Parse step count (indices 12-13)
      final stepCount = (data[12] << 8) | data[13];

      // Parse activity type (index 14)
      final activityType = _parseActivityType(data[14]);

      // Parse battery (index 15)
      _batteryLevel = data[15];

      // Create accelerometer data from first byte pattern
      final accelData = _generateAccelFromActivity(activityType);

      // Create gyroscope data from second byte pattern
      final gyroData = _generateGyroFromActivity(activityType);

      return SensorReading(
        timestamp: DateTime.now(),
        temperatures: temperatures,
        pressures: pressures,
        spO2: spO2,
        heartRate: heartRate,
        accelerometer: accelData,
        gyroscope: gyroData,
        stepCount: stepCount,
        activityType: activityType,
        batteryLevel: _batteryLevel,
      );
    } catch (e) {
      debugPrint('Parse error: $e');
      return null;
    }
  }

  /// Parse activity type from byte
  ActivityType _parseActivityType(int byte) {
    switch (byte & 0x0F) {
      case 0:
        return ActivityType.resting;
      case 1:
        return ActivityType.sitting;
      case 2:
        return ActivityType.standing;
      case 3:
        return ActivityType.walking;
      case 4:
        return ActivityType.running;
      default:
        return ActivityType.unknown;
    }
  }

  /// Generate placeholder accelerometer data based on activity
  AccelerometerData _generateAccelFromActivity(ActivityType activity) {
    switch (activity) {
      case ActivityType.walking:
      case ActivityType.running:
        return AccelerometerData(x: 0.5, y: 0.3, z: 9.8);
      case ActivityType.standing:
        return AccelerometerData(x: 0.1, y: 0.1, z: 9.8);
      default:
        return AccelerometerData(x: 0.0, y: 0.0, z: 9.8);
    }
  }

  /// Generate placeholder gyroscope data based on activity
  GyroscopeData _generateGyroFromActivity(ActivityType activity) {
    switch (activity) {
      case ActivityType.walking:
        return GyroscopeData(x: 5.0, y: 3.0, z: 2.0);
      case ActivityType.running:
        return GyroscopeData(x: 10.0, y: 5.0, z: 4.0);
      default:
        return GyroscopeData(x: 0.5, y: 0.5, z: 0.5);
    }
  }
}
