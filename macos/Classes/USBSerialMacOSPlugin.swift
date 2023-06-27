import Foundation
import FlutterMacOS

// NSObject: The root class of most Objective-C class hierarchies, from which subclasses inherti
// a basic interace to the runtime system and the ability to behave as Objective-C objects

public class USBSerialMacOSPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    let registery: FlutterTextureRegistry
    
    // Sink for publishing event changes
    // Suitable for capturing the results of asynchronous computations,
    // which can complete with a value or an error.
    // Designed to handle asynchronous events from Streams
    var sink: FlutterEventSink!
    var fileDescriptor: Int32?
    
    var connectedDevice:SerialDevice?
    var devices:[SerialDevice] = []
    
    //make sure that stm32DeviceMonitor always exist
    let deviceMonitor = SerialDeviceMonitor()
    
    // Setting up the method and event channels
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = USBSerialMacOSPlugin(registrar.textures);
        let method = FlutterMethodChannel(name:"usbserial/macos/method", binaryMessenger: registrar.messenger)
        
        // Channel for communicating with platform plugins using event streams
        let event = FlutterEventChannel(name:"usbserial/macos/event", binaryMessenger: registrar.messenger)
        registrar.addMethodCallDelegate(instance, channel: method)
        event.setStreamHandler(instance)
    }
    
    init(_ registery:FlutterTextureRegistry){
        self.registery = registery
        super.init()
        applicationDidFinishLaunching();
    }

    // FlutterStreamHandler
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }
    
    // FlutterStreamHandler
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
    
    func applicationDidFinishLaunching(){//(_ aNotification: Notification) {
        let deviceDaemon = Thread(target: self.deviceMonitor, selector:#selector(self.deviceMonitor.start), object: nil)
        deviceDaemon.start()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.serialDeviceAdded),
            name: .SerialDeviceAdded,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.serialDeviceRemoved),
            name: .SerialDeviceRemoved,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.serialReadStream),
            name: .SerialReadStream,
            object: nil
        )
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "usbDevices":
            return result(["usbDevices":findDevices()]);
        case "connectToPort":
            guard let arg = call.arguments as? [String:Any?],
                  let data = arg["port"] as? String else{
                return result(FlutterError(code: "connectToPort", message: "No port in call!", details: nil))
            }
            
            self.connectedDevice = self.devices.first(where: { $0.deviceInfo.path == data})
            if(self.connectedDevice == nil){
                return result(["opened":false])
            }
            do{
                try connectedDevice!.openPort(toReceive: true, andTransmit: true)

                return result(["opened":true])
            }
            catch PortError.invalidPath{
                return result(FlutterError(code: "connectToPort", message: "Invalid Path!", details: nil))
            }
            catch PortError.mustReceiveOrTransmit{
                return result(FlutterError(code: "connectToPort", message: "Must Receive Or Transmit!", details: nil))
            }
            catch PortError.failedToOpen{
                return result(FlutterError(code: "connectToPort", message: "Failed To Open!", details: nil))
            }
            catch{
                return result(FlutterError(code: "connectToPort", message: "Other Unknown Error!", details: nil))
            }
            
        case "setPortSettings":
            let arg = call.arguments as? [String:Any?]
            
            connectedDevice?.setSettings(
                receiveRate: BaudRate.init(rawValue: arg!["receiveRate"] as? Int ?? 0)!,
                transmitRate: BaudRate.init(rawValue: arg!["transmitRate"] as? Int ?? 0)!,
                minimumBytesToRead: arg!["minimumBytesToRead"] as? Int ?? 0,
                timeout: arg!["timeout"] as? Int ?? 0,
                parityType: ParityType.init(rawValue: arg!["parityType"] as? Int ?? 0)!,
                sendTwoStopBits: arg!["sendTwoStopBits"] as? Bool ?? false,
                dataBitsSize: DataBitsSize.init(rawValue: arg!["dataBitsSize"] as? Int ?? 3)!,
                useSoftwareFlowControl: arg!["useSoftwareFlowControl"] as? Bool ?? false,
                processOutput: arg!["processOutput"] as? Bool ?? true
            )

            return result(["setSettings":true])
        case "writeString":
            guard let arg = call.arguments as? [String:Any?],
            let data = arg["data"] as? String else{
                return result(FlutterError(code: "sendData", message: "No data in call!", details: nil))
            }
            var bytesWritten:Int? = 0
            do{
                bytesWritten = try connectedDevice?.writeString(data)
            }
            catch{
                return result(FlutterError(code: "sendData", message: "Port Not Open!", details: nil))
            }
            return result(["numBytes":bytesWritten])
        case "writeBytes":
            guard let arg = call.arguments as? [String:Any?],
            let uintInt8List = arg["data"] as? FlutterStandardTypedData else{
                return result(FlutterError(code: "sendData", message: "No data in call!", details: nil))
            }
            let byte = [UInt8](uintInt8List.data)
            let length = arg["length"] as? Int ?? 0
            let data = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
            
            for i in 0...length{
                data.advanced(by: i).pointee = byte[i]
            }
            
            var bytesWritten:Int? = 0
            do{
                bytesWritten = try connectedDevice?.writeBytes(from: data, size: length)
            }
            catch{
                return result(FlutterError(code: "sendData", message: "Port Not Open!", details: nil))
            }
            return result(["numBytes":bytesWritten])
        case "disconnectFromPort":
            connectedDevice?.closePort()
            return result(["didDisconnect":connectedDevice?.fileDescriptor == nil])
        default:
            return result(FlutterMethodNotImplemented)
        }
    }

    
    func findDevices() -> [String:Any]{
        var ports: [String:Any] = [:];
        var i = 0;
        self.devices.forEach { device in
            ports[i.description] = device.deviceInfo.toFlutter()
            i += 1
        }
        return ports
    }
    
    @objc func serialReadStream(notification: NSNotification) {
        guard let nobj = notification.object as? NSDictionary else {
            return
        }
        
        guard let receivedData:String = nobj["received"] as? String else {
            self.sink?([
                "event": "receivedTransmission",
                "data": "ERROR"
            ])
            return
        }
        
        self.sink?([
            "event": "receivedTransmission",
            "data": receivedData
        ])
    }
    @objc func serialDeviceAdded(notification: NSNotification) {
        guard let nobj = notification.object as? NSDictionary else {
            return
        }
        
        guard let deviceInfo:SerialDeviceInfo = nobj["device"] as? SerialDeviceInfo else {
            return
        }
        let device = SerialDevice(deviceInfo)
        self.devices.append(device)
        self.sink?([
            "event": "addDevice",
            "data": device.deviceInfo.toFlutter()
        ])
    }
    
    @objc func serialDeviceRemoved(notification: NSNotification) {
        guard let nobj = notification.object as? NSDictionary else {
            return
        }
        
        guard let deviceInfo:SerialDeviceInfo = nobj["device"] as? SerialDeviceInfo else {
            return
        }

        if let index = self.devices.firstIndex(where: { $0.deviceInfo.path == deviceInfo.path }) {
            self.devices.remove(at: index)
            if (deviceInfo.path == self.connectedDevice?.deviceInfo.path) {
                self.connectedDevice = nil
            }
            self.sink?([
                "event": "removeDevice",
                "data": deviceInfo.toFlutter()
            ])
        }
    }
}
