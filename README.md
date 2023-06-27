# usbserial\_macos

[![Pub Version](https://img.shields.io/pub/v/usbserial_macos)](https://pub.dev/packages/usbserial_macos)
[![analysis](https://github.com/Knightro63/usbserial_macos/actions/workflows/flutter.yml/badge.svg)](https://github.com/Knightro63/usbserial_macos/actions/)
[![Star on Github](https://img.shields.io/github/stars/Knightro63/usbserial_macos.svg?style=flat&logo=github&colorB=deeppink&label=stars)](https://github.com/Knightro63/usbserial_macos)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

This ia a Flutter plugin that enables usb serial connections from macos to any serial device.

## Example

You need to first import 'package:usbserial_macos/usbSerial.dart';

```dart
  // Class from usbserial.dart package
  USBSerialMacOS usbserial = USBSerialMacOS();
  late StreamSubscription usbSubscription;
  List<USBDevice> usbDevices = [];
  String received = '';
  USBDevice? connectedDevice;

  @override
  void initState(){
    usbserial.transmission.listen((event) { 
      setState(() {
        received += '$event\n';
      });
    });
    usbserial.devices.listen((event) {
      print(event);
      if(event.added){
        usbDevices.add(event);
      }
      else{
        event.added = true;
        usbDevices.remove(event);
      }
    });
    usbserial.findDevices().then((value){
      usbDevices = value;
    });
    
    super.initState();
  }

  @override
  void dispose(){
    usbserial.dispose();
    super.dispose();
  }

  void sendString(){
    if(toSend.text != ''){
      if(usbserial.isPortOpened){
        usbserial.writeString('${toSend.text}\n').then((written){
          print(written);
        });
      }
      toSend.clear();
    }
  }
```

## Example app

Find the example for each of the packages in there example folder.

## Contributing

Contributions are welcome.
In case of any problems look at [existing issues](https://github.com/Knightro63/usbserial_macos/issues), if you cannot find anything related to your problem then open an issue.
Create an issue before opening a [pull request](https://github.com/Knightro63/usbserial_macos/pulls) for non trivial fixes.
In case of trivial fixes open a [pull request](https://github.com/Knightro63/usbserial_macos/pulls) directly.

