import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../components/reading_chart.dart';

class DeviceDetailPage extends StatefulWidget {
  final String deviceId;

  const DeviceDetailPage({super.key, required this.deviceId});

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  final ApiClient _api = ApiClient();
  DeviceReadings? _readings;
  Device? _device;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReadings();
    // Refresh every 15 seconds
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        _loadReadings();
        _startPeriodicRefresh();
      }
    });
  }

  Future<void> _loadReadings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load device info and readings
      final devices = await _api.getDevices();
      final device = devices.firstWhere(
        (d) => d.deviceId == widget.deviceId,
        orElse: () => Device(deviceId: widget.deviceId, status: "OFFLINE"),
      );
      final readings = await _api.getDeviceReadings(widget.deviceId, limit: 100);
      setState(() {
        _device = device;
        _readings = readings;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Device: ${widget.deviceId}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReadings,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadReadings,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _readings == null || _readings!.readings.isEmpty
                  ? const Center(child: Text('No readings available'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Device status info
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Device Status',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Device ID: ${widget.deviceId}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildStatusExplanation(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Latest reading card
                          if (_readings!.readings.isNotEmpty) ...[
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Latest Refractometry Reading',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildReadingValueWithAlerts(),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Measured: ${_formatDateTime(_readings!.readings.first.ts)}',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    if (_readings!.readings.first.temperatureC != null)
                                      Text(
                                        'Ambient temp: ${_readings!.readings.first.temperatureC!.toStringAsFixed(1)}°C',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Target and Alert Boundaries
                            if (_device != null && (_device!.targetRi != null || _device!.alertLow != null || _device!.alertHigh != null)) ...[
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Target & Alert Boundaries',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (_device!.targetRi != null)
                                        _buildBoundaryRow('Target RI', _device!.targetRi!, Colors.blue),
                                      if (_device!.alertLow != null)
                                        _buildBoundaryRow('Alert Low', _device!.alertLow!, Colors.orange),
                                      if (_device!.alertHigh != null)
                                        _buildBoundaryRow('Alert High', _device!.alertHigh!, Colors.red),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                          // Chart
                          const Text(
                            'Time Series',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 300,
                            child: ReadingChart(readings: _readings!.readings),
                          ),
                          const SizedBox(height: 24),
                          // Readings table
                          const Text(
                            'Recent Refractometry Readings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Showing ${_readings!.readings.length} reading(s)',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          _buildReadingsTable(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildReadingsTable() {
    return Card(
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
        },
        children: [
          const TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey)),
            ),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Time', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Refractometry', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          ..._readings!.readings.take(20).map((reading) {
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_formatDateTime(reading.ts)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(reading.value.toStringAsFixed(4)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(reading.unit),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusExplanation() {
    final status = _device?.status ?? "OFFLINE";
    
    String explanation;
    Color color;
    
    switch (status.toUpperCase()) {
      case "OK":
        explanation = "OK: Device seen within last 15 minutes - actively reporting refractometry data";
        color = Colors.green;
        break;
      case "STALE":
        explanation = "STALE: Device seen within last 24 hours but > 15 minutes ago - may be delayed or on scheduled intervals";
        color = Colors.orange;
        break;
      case "OFFLINE":
        explanation = "OFFLINE: Device not seen in last 24 hours - check device power and network connection";
        color = Colors.red;
        break;
      default:
        explanation = "Unknown status";
        color = Colors.grey;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                explanation,
                style: TextStyle(color: color, fontSize: 12),
              ),
            ),
          ],
        ),
        if (_device?.lastSeenAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Last seen: ${_formatDateTime(_device!.lastSeenAt!)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildReadingValueWithAlerts() {
    final reading = _readings!.readings.first;
    final value = reading.value;
    final device = _device;
    
    // Determine if reading is outside alert boundaries
    bool isAlert = false;
    Color valueColor = Colors.blue;
    
    if (device != null) {
      if (device.alertLow != null && value < device.alertLow!) {
        isAlert = true;
        valueColor = Colors.red;
      } else if (device.alertHigh != null && value > device.alertHigh!) {
        isAlert = true;
        valueColor = Colors.red;
      } else if (device.targetRi != null) {
        // Check if close to target (within 0.001)
        final diff = (value - device.targetRi!).abs();
        if (diff <= 0.001) {
          valueColor = Colors.green;
        }
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value.toStringAsFixed(4),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              reading.unit,
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        if (isAlert)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Outside alert boundaries - manual investigation recommended',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBoundaryRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value.toStringAsFixed(4),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
