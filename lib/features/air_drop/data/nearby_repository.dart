import 'package:nearby_connections/nearby_connections.dart';
import '../../../core/models/media_item.dart';

/// Data layer for Air-Drop — wraps the nearby_connections API.
class NearbyRepository {
  static const String _serviceId = 'com.petersmartlink.otya.airdrop';
  static const String _userName = 'played_user';

  /// Starts advertising this device so others can discover it.
  Future<void> startAdvertising({
    required void Function(String endpointId, ConnectionInfo info)
        onConnectionInitiated,
    required void Function(String endpointId, Status status)
        onConnectionResult,
    required void Function(String endpointId) onDisconnected,
  }) async {
    await Nearby().startAdvertising(
      _userName,
      Strategy.P2P_CLUSTER,
      onConnectionInitiated: onConnectionInitiated,
      onConnectionResult: onConnectionResult,
      onDisconnected: onDisconnected,
      serviceId: _serviceId,
    );
  }

  /// Starts discovering nearby devices.
  Future<void> startDiscovery({
    required void Function(String id, String name, String serviceId)
        onEndpointFound,
    required void Function(String? id) onEndpointLost,
  }) async {
    await Nearby().startDiscovery(
      _userName,
      Strategy.P2P_CLUSTER,
      onEndpointFound: onEndpointFound,
      onEndpointLost: onEndpointLost,
      serviceId: _serviceId,
    );
  }

  /// Requests a connection to a discovered endpoint.
  Future<void> requestConnection({
    required String endpointId,
    required void Function(String endpointId, ConnectionInfo info)
        onConnectionInitiated,
    required void Function(String endpointId, Status status)
        onConnectionResult,
    required void Function(String endpointId) onDisconnected,
  }) async {
    await Nearby().requestConnection(
      _userName,
      endpointId,
      onConnectionInitiated: onConnectionInitiated,
      onConnectionResult: onConnectionResult,
      onDisconnected: onDisconnected,
    );
  }

  /// Accepts an incoming connection.
  Future<void> acceptConnection({
    required String endpointId,
    required void Function(String endpointId, Payload payload)
        onPayloadReceived,
    void Function(String endpointId, PayloadTransferUpdate update)?
        onPayloadTransferUpdate,
  }) async {
    await Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: onPayloadReceived,
      onPayloadTransferUpdate: onPayloadTransferUpdate ?? (_, __) {},
    );
  }

  /// Sends a file payload to a connected endpoint.
  Future<void> sendFile({
    required String endpointId,
    required MediaItem item,
  }) async {
    await Nearby().sendFilePayload(endpointId, item.filePath);
  }

  /// Stops all discovery and advertising.
  Future<void> stopAll() async {
    await Nearby().stopDiscovery();
    await Nearby().stopAdvertising();
    await Nearby().stopAllEndpoints();
  }
}
