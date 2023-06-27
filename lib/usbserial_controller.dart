library usbserial;

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'usbdevices.dart';

// Sets up a class that contains methods that communicates with the Swift file
class USBSerialMacOS {
  // Method Channel
  static const MethodChannel _methodChannel = MethodChannel('usbserial/macos/method');
  static const EventChannel _eventChannel = EventChannel('usbserial/macos/event');
  StreamSubscription? events;

  late StreamController<USBDevice> deviceController;
  Stream<USBDevice> get devices => deviceController.stream;

  late StreamController<String> transmissionController;
  Stream<String> get transmission => transmissionController.stream;

  bool isPortOpened = false;

  USBSerialMacOS(){
    events = _eventChannel
    .receiveBroadcastStream()
    .listen((data) => handleEvent(data as Map));

    deviceController = StreamController.broadcast();
    transmissionController = StreamController.broadcast();
  }

  // Figures out what port can be connected to
  Future<List<USBDevice>> findDevices() async {
    try {
      final output = await _methodChannel.invokeMapMethod<String, Map>(
        'usbDevices',
      );
      Map? dev = output!['usbDevices'];
      List<USBDevice> devNative = [];
      if(dev != null){
        for(String i in dev.keys){
          devNative.add(USBDevice.fromNative(dev[i], true));
        }
      }
      return devNative;
    } catch (e) {
      debugPrint('$e');
    }

    return [];
  }

  // Figures out what port can be connected to
  Future<bool?> setSettings(PortSettings settings) async {
    try {
      final output = await _methodChannel.invokeMapMethod<String, bool>(
        'setPortSettings', {
          'receiveRate': settings.receiveRate.index,
          'transmitRate': settings.transmitRate.index,
          'minimumBytesToRead': settings.minimumBytesToRead,
          'timeout': settings.timeout,
          'parityType': settings.parityType.index,
          'sendTwoStopBits': settings.sendTwoStopBits,
          'dataBitsSize': settings.dataBitsSize.index,
          'useSoftwareFlowControl': settings.useSoftwareFlowControl,
          'processOutput': settings.processOutput,
        }
      );
      return output!['setSettings'];
    } catch (e) {
      debugPrint('$e');
    }

    return false;
  }

  Future<int?> writeString(String data) async {
    if(!isPortOpened) return null;
    try {
      final output = await _methodChannel.invokeMapMethod<String, dynamic>(
        'writeString',
        {'data': data},
      );
      return output!['numBytes'];
    } catch (e) {
      debugPrint('$e');
    }

    return null;
  }
  Future<int?> writeBytes(Uint8List data) async {
    if(!isPortOpened) return null;
    try {
      final output = await _methodChannel.invokeMapMethod<String, dynamic>(
        'writeBytes',
        {
          'data': data,
          'length': data.length
        },
      );
      return output!['numBytes'];
    } catch (e) {
      debugPrint('$e');
    }

    return null;
  }
  Future<bool?> openPort(String port) async {
    if(isPortOpened) return true;
    try {
      final output = await _methodChannel.invokeMapMethod<String, bool>(
        'connectToPort',
        {'port': port},
      );
      isPortOpened = output!['opened']!;
      return isPortOpened;
    } catch (e) {
      debugPrint('$e');
    }

    return false;
  }

  Future<bool> closePort() async {
    if(!isPortOpened) return true;
    try {
      final output = await _methodChannel.invokeMapMethod<String, bool>(
        'disconnectFromPort',
      );
      print(output);
      isPortOpened = !output!['didDisconnect']!;
      return !isPortOpened;
    } catch (e) {
      debugPrint('$e');
    }

    return false;
  }

 void handleEvent(Map event) {
    final eventType = event['event'];
    final data = event['data'];
    switch (eventType) {
      case 'receivedTransmission':
        print(data);
        transmissionController.add(data);
        break;
      case 'addDevice':
        final device = USBDevice.fromNative(data as Map,true);
        deviceController.add(device);
        break;
      case 'removeDevice':
        final device = USBDevice.fromNative(data as Map,false);
        deviceController.add(device);
        break;
      default:
        throw UnimplementedError();
    }
  }

  /// Disposes the MobileScannerController and closes all listeners.
  void dispose() {
    closePort();
    transmissionController.close();
    deviceController.close();
    events?.cancel();
    events = null;
  }
}
