/// Represents a discovered Vizio TV and its network configuration.
///
/// Stores connectivity metadata and optional pairing credentials to enable
/// caching and automatic reconnection across DHCP IP address changes.
///
/// * [id] — The unique identifier or MAC address of the TV (used as a primary key over [ipAddress]).
/// * [name] — The human-readable cast name assigned to the device.
/// * [ipAddress] — Target local IP address for HTTP API requests.
/// * [port] — API port for command transmission (typically `7345` or `9000`).
/// * [authToken] — Optional secure token generated after pairing to authorize remote control actions.
/// * [lastSeen] — Timestamp indicating when the TV was last verified on the local network.
class DiscoveredTv {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final DateTime lastSeen;
  final String? authToken;

  DiscoveredTv({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.lastSeen,
    this.authToken,
  });

  bool get isPaired => authToken != null && authToken!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ipAddress': ipAddress,
    'port': port,
    'lastSeen': lastSeen.toIso8601String(),
    'authToken': authToken,
  };

  factory DiscoveredTv.fromJson(
    Map<String, dynamic> json, {
    String? authToken,
  }) {
    return DiscoveredTv(
      id: json['id'] as String,
      name: json['name'] as String,
      ipAddress: json['ipAddress'] as String,
      port: (json['port'] is int)
          ? json['port'] as int
          : int.tryParse('${json['port']}') ?? 7345,
      authToken: authToken ?? (json['authToken'] as String?),
      lastSeen: DateTime.parse(json['lastSeen'] as String),
    );
  }

  DiscoveredTv copyWith({
    String? ipAddress,
    String? name,
    String? authToken,
    DateTime? lastSeen,
    int? port,
  }) {
    return DiscoveredTv(
      id: id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      authToken: authToken ?? this.authToken,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
