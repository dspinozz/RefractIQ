import 'package:flutter/material.dart';
import '../api/client.dart';
import '../components/status_badge.dart';

class DeviceTable extends StatelessWidget {
  final List<Device> devices;
  final Function(Device) onDeviceTap;

  const DeviceTable({
    super.key,
    required this.devices,
    required this.onDeviceTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(device.name ?? device.deviceId),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: ${device.deviceId}'),
                if (device.lastSeenAt != null)
                  Text(
                    'Last seen: ${_formatDateTime(device.lastSeenAt!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                if (device.latestReading != null)
                  Text(
                    'Latest: ${device.latestReading!.value.toStringAsFixed(4)} ${device.latestReading!.unit}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            trailing: StatusBadge(status: device.status),
            onTap: () => onDeviceTap(device),
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
