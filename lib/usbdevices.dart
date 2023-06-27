

enum BaudRate {
  baud0,
  baud50,
  baud75,
  baud110,
  baud134,
  baud150,
  baud200,
  baud300,
  baud600,
  baud1200,
  baud1800,
  baud2400,
  baud4800,
  baud9600,
  baud19200,
  baud38400,
  baud57600,
  baud115200,
  baud230400,
}

enum DataBitsSize { bits5, bits6, bits7, bits8 }

enum ParityType { none, even, odd }

class PortSettings {
  PortSettings(
      {this.receiveRate = BaudRate.baud9600,
      this.transmitRate = BaudRate.baud9600,
      this.minimumBytesToRead = 1,
      this.timeout = 3600,
      this.parityType = ParityType.none,
      this.sendTwoStopBits = false,
      this.dataBitsSize = DataBitsSize.bits8,
      this.useSoftwareFlowControl = false,
      this.processOutput = false});

  BaudRate receiveRate;
  BaudRate transmitRate;
  int minimumBytesToRead;
  int timeout;
  ParityType parityType;
  bool sendTwoStopBits;
  DataBitsSize dataBitsSize;
  bool useSoftwareFlowControl;
  bool processOutput;
}

class USBDevice{
  USBDevice({
    required this.path,
    this.name,
    this.vendorName,
    this.serialNumber,
    this.vendorId,
    this.productId,
    required this.added
  });

  bool added;
  String path;
  String? name;
  String? vendorName;
  String? serialNumber;
  int? vendorId;
  int? productId;


  static USBDevice fromNative(Map data,bool isBeingAdded){
    return USBDevice(
      path: data['path'],
      name: data['name'],
      vendorName: data['vendorName'],
      serialNumber: data['serialNumber'],
      vendorId: data['vendorId'],
      productId: data['productId'],
      added: isBeingAdded
    );
  }

  @override
  String toString(){
    Map temp = {
      'path': path,
      'name': name,
      'vendorName': vendorName,
      'serialNumber': serialNumber,
      'vendorId': vendorId,
      'productId': productId,
    };

    return temp.toString();
  }
}