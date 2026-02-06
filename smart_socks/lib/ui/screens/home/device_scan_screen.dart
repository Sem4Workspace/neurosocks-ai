import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/sensor_provider.dart';

/// Screen for scanning and connecting to BLE devices
class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  late Future<List<ScanResult>> _scanFuture;
  BluetoothDevice? _connectingDevice;
  String? _connectingError;

  @override
  void initState() {
    super.initState();
    _scanFuture = _startScan();
  }

  Future<List<ScanResult>> _startScan() async {
    try {
      final sensorProvider = context.read<SensorProvider>();
      final results = await sensorProvider.realBleService.scanForDevices(timeoutSeconds: 8);
      return results;
    } catch (e) {
      debugPrint('Scan error: $e');
      if (mounted) {
        setState(() {
          _connectingError = 'Scan failed: $e';
        });
      }
      return [];
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _connectingDevice = device;
      _connectingError = null;
    });

    try {
      final sensorProvider = context.read<SensorProvider>();
      bool connected = await sensorProvider.realBleService.connectToDevice(
        device,
      );

      if (connected) {
        // Update sensor provider state
        await sensorProvider.connect();

        if (!mounted) return;

        // Show success and go back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device connected successfully!'),
            duration: Duration(seconds: 2),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _connectingError = 'Connection failed: $e';
        _connectingDevice = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_connectingError!),
            duration: const Duration(seconds: 3),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Devices'), elevation: 0),
      body: FutureBuilder<List<ScanResult>>(
        future: _scanFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final devices = snapshot.data ?? [];

          if (devices.isEmpty) {
            return _buildEmptyState();
          }

          return _buildDeviceList(devices);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 24),
          const Text(
            'Scanning for devices...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure your smart socks are powered on',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_disabled,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 24),
          const Text(
            'No devices found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure your smart socks are powered on\nand Bluetooth is enabled',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _scanFuture = _startScan();
              });
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 24),
          const Text(
            'Scan failed',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _scanFuture = _startScan();
              });
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(List<ScanResult> devices) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final result = devices[index];
        final device = result.device;
        final isConnecting = _connectingDevice?.remoteId == device.remoteId;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.bluetooth_connected,
                color: AppColors.primary,
              ),
            ),
            title: Text(
              device.platformName.isNotEmpty
                  ? device.platformName
                  : 'Unnamed Device',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'ID: ${device.remoteId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Signal: ${result.rssi} dBm',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            trailing: isConnecting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: () => _connectToDevice(device),
                    child: const Text('Connect'),
                  ),
          ),
        );
      },
    );
  }
}
