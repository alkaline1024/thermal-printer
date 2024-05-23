import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform/flutter_pos_printer_platform.dart';
import 'package:hive/hive.dart';

class BluetoothPrinter extends ChangeNotifier {
  StreamSubscription<BTStatus>? _subscriptionBtStatus;
  StreamSubscription<PrinterDevice>? _subscription;
  static const PrinterType _defaultPrinterType = PrinterType.bluetooth;
  List<Device> devices = [];
  Device? connectedPrinter;
  bool _isConnected = false;
  bool _scanning = false;

  BluetoothPrinter() {
    _subscriptionBtStatus =
        PrinterManager.instance.stateBluetooth.listen((status) {
      if (status == BTStatus.connected) {
        _isConnected = true;
      } else if (status == BTStatus.none) {
        _isConnected = false;
      }
      notifyListeners();
    });
    scan();
    loadRegisteredDevice();
  }

  bool get isConnected => _isConnected;
  bool get scanning => _scanning;

  bool isRegisterdBluetoothDevice() {
    if (Hive.box<Map>('bluetoothPrinterBox').get(0) != null) {
      return true;
    } else {
      return false;
    }
  }

  void deRegisterBluetoothDevice() async {
    await Hive.box<Map>('bluetoothPrinterBox').delete(0);
    await disconnectDevice();
  }

  void registerBluetoothDevice(device) async {
    await Hive.box<Map>('bluetoothPrinterBox').put(0, {
      'deviceName': device.deviceName,
      "address": device.address!,
    });
  }

  void loadRegisteredDevice() async {
    final bluetoothPrinterBox = await Hive.openBox<Map>('bluetoothPrinterBox');
    Map? registeredDevice = bluetoothPrinterBox.get(0);
    // debugPrint('>>> reg ${registeredDevice.toString()}');
    if (registeredDevice == null) return;
    Device device = Device(
        address: registeredDevice['address'],
        deviceName: registeredDevice['deviceName']);
    await connectDevice(device, reconnect: true);
  }

  void scan({PrinterType type = _defaultPrinterType, bool isBle = false}) {
    // Find printers
    devices.clear();
    _scanning = true;
    notifyListeners();
    _subscription = PrinterManager.instance
        .discovery(type: type, isBle: isBle)
        .listen((device) {
      devices.add(Device(
        deviceName: device.name,
        address: device.address,
        isBle: isBle,
        vendorId: device.vendorId,
        productId: device.productId,
        typePrinter: _defaultPrinterType,
      ));
      notifyListeners();
    }, onDone: () {
      debugPrint('SCAN DONE');
      _scanning = false;
      notifyListeners();
    });
  }

  Future<void> sendBytesToPrint(List<int> bytes,
      {PrinterType type = _defaultPrinterType}) async {
    await PrinterManager.instance.send(type: type, bytes: bytes);
  }

  Future<void> connectDevice(Device selectedPrinter,
      {PrinterType type = _defaultPrinterType,
      bool reconnect = false,
      bool isBle = false,
      String? ipAddress}) async {
    switch (type) {
      // only windows and android
      case PrinterType.usb:
        await PrinterManager.instance.connect(
            type: type,
            model: UsbPrinterInput(
                name: selectedPrinter.deviceName,
                productId: selectedPrinter.productId,
                vendorId: selectedPrinter.vendorId));
        break;
      // only iOS and android
      case PrinterType.bluetooth:
        connectedPrinter = selectedPrinter;
        registerBluetoothDevice(selectedPrinter);
        await PrinterManager.instance.connect(
            type: type,
            model: BluetoothPrinterInput(
                name: selectedPrinter.deviceName,
                address: selectedPrinter.address!,
                isBle: isBle,
                autoConnect: reconnect));
        break;
      case PrinterType.network:
        await PrinterManager.instance.connect(
            type: type,
            model: TcpPrinterInput(
                ipAddress: ipAddress ?? selectedPrinter.address!));
        break;
      default:
    }
  }

  Future<void> disconnectDevice(
      {PrinterType type = _defaultPrinterType}) async {
    _isConnected = await PrinterManager.instance.disconnect(type: type);
    connectedPrinter = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscriptionBtStatus?.cancel();
    _subscription?.cancel();
    Hive.box<Device>('bluetoothPrinterBox').close();
    super.dispose();
  }
}

class Device {
  String? deviceName;
  String? address;
  String? vendorId;
  String? productId;
  bool? isBle;

  PrinterType typePrinter;

  Device({
    this.deviceName,
    this.address,
    this.vendorId,
    this.productId,
    this.typePrinter = PrinterType.bluetooth,
    this.isBle = false,
  });
}
