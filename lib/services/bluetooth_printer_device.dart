class BluetoothPrinterDevice {
  final String name;
  final String address;
  final bool isConnected;

  const BluetoothPrinterDevice({
    required this.name,
    required this.address,
    this.isConnected = false,
  });

  BluetoothPrinterDevice copyWith({
    String? name,
    String? address,
    bool? isConnected,
  }) {
    return BluetoothPrinterDevice(
      name: name ?? this.name,
      address: address ?? this.address,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothPrinterDevice &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;
}

