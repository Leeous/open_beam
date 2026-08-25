enum TvBrand { roku, vizio, lg, samsung }

class PairedTvDevice {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final TvBrand brand;
  final String? authToken;

  const PairedTvDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.brand,
    this.authToken,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ipAddress': ipAddress,
    'port': port,
    'brand': brand,
    authToken ?? 'authToken': authToken,
  };

  factory PairedTvDevice.fromJson(Map<String, dynamic> json) => PairedTvDevice(
    id: json['id'] as String,
    name: json['name'] as String,
    ipAddress: json['ipAddress'] as String,
    port: json['port'] as int,
    brand: TvBrand.values.byName(json['brand'] as String),
    authToken: json['authToken'] as String?,
  );
}
