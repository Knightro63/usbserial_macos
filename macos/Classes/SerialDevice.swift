//
//  SerialDevice.swift
//  USBDeviceSwift
//
//  Created by Artem Hruzd on 3/9/18.
//  Copyright © 2018 Artem Hruzd. All rights reserved.
//
import Foundation
import IOKit.serial

public enum PortError: Int32, Error {
    case failedToOpen = -1 // refer to open()
    case invalidPath
    case mustReceiveOrTransmit
    case mustBeOpen
    case stringsMustBeUTF8
    case deviceNotConnected
    case unableToConvertByteToCharacter
}

// Added the rest of the baud rates
public enum BaudRate: Int{
    case baud0 = 0
    case baud50
    case baud75
    case baud110
    case baud134
    case baud150
    case baud200
    case baud300
    case baud600
    case baud1200
    case baud1800
    case baud2400
    case baud4800
    case baud9600
    case baud19200
    case baud38400
    case baud57600
    case baud115200
    case baud230400

    var speedValue: speed_t {
        switch self {
        case .baud0:
            return speed_t(B0)
        case .baud50:
            return speed_t(B50)
        case .baud75:
            return speed_t(B75)
        case .baud110:
            return speed_t(B110)
        case .baud134:
            return speed_t(B134)
        case .baud150:
            return speed_t(B150)
        case .baud200:
            return speed_t(B200)
        case .baud300:
            return speed_t(B300)
        case .baud600:
            return speed_t(B600)
        case .baud1200:
            return speed_t(B1200)
        case .baud1800:
            return speed_t(B1800)
        case .baud2400:
            return speed_t(B2400)
        case .baud4800:
            return speed_t(B4800)
        case .baud9600:
            return speed_t(B9600)
        case .baud19200:
            return speed_t(B19200)
        case .baud38400:
            return speed_t(B38400)
        case .baud57600:
            return speed_t(B57600)
        case .baud115200:
            return speed_t(B115200)
        case .baud230400:
            return speed_t(B230400)
        }
    }
}

public enum DataBitsSize:Int {
    
    case bits5 = 0
    case bits6
    case bits7
    case bits8
    
    var flagValue: tcflag_t {
        switch self {
        case .bits5:
            return tcflag_t(CS5)
        case .bits6:
            return tcflag_t(CS6)
        case .bits7:
            return tcflag_t(CS7)
        case .bits8:
            return tcflag_t(CS8)
        }
    }
}

public enum ParityType: Int{
    case none = 0
    case even
    case odd
    
    var parityValue: tcflag_t {
        switch self {
        case .none:
            return 0
        case .even:
            return tcflag_t(PARENB)
        case .odd: return tcflag_t(PARENB | PARODD)
        }
    }
}

public extension Notification.Name {
    static let SerialDeviceAdded = Notification.Name("SerialDeviceAdded")
    static let SerialReadStream = Notification.Name("SerialReadStream")
    static let SerialDeviceRemoved = Notification.Name("SerialDeviceRemoved")
}

public struct SerialDeviceInfo {
    public let path:String
    public var name:String? // USB Product Name
    public var vendorName:String? //USB Vendor Name
    public var serialNumber:String? //USB Serial Number
    public var vendorId:Int? //USB Vendor id
    public var productId:Int? //USB Product id
    
    init(path:String) {
        self.path = path
    }
    
    func toFlutter() -> [String:Any?]{
        return [
            "path": path,
            "name": name,
            "vendorName": vendorName,
            "serialNumber": serialNumber,
            "vendorId": vendorId,
            "productId": productId
        ]
    }
}

extension SerialDeviceInfo: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine("\(path)")
    }
    
    public static func ==(lhs: SerialDeviceInfo, rhs: SerialDeviceInfo) -> Bool {
        return lhs.path == rhs.path
    }
}

class SerialDevice {
    var deviceInfo:SerialDeviceInfo
    var fileDescriptor:Int32?
    var isNewRead:Bool = true
    
    /// A dispatch source to monitor a file descriptor created from the directory.
    private var folderMonitorSource: DispatchSourceFileSystemObject?
    
    required init(_ deviceInfo:SerialDeviceInfo) {
        self.deviceInfo = deviceInfo
    }
    
    func setSettings(receiveRate: BaudRate,
                            transmitRate: BaudRate,
                            minimumBytesToRead: Int,
                            timeout: Int = 0,
                            parityType: ParityType = .none,
                            sendTwoStopBits: Bool = false,
                            dataBitsSize: DataBitsSize = .bits8,
                            useSoftwareFlowControl: Bool = false,
                            processOutput: Bool = false) {
        
        guard let fileDescriptor = fileDescriptor else {
            return
        }
        
        // Set up the control structure
        var settings = termios()
        
        // Get options structure for the port
        tcgetattr(fileDescriptor, &settings)
        
        // Set baud rates
        cfsetispeed(&settings, receiveRate.speedValue)
        cfsetospeed(&settings, transmitRate.speedValue)
        
        // Enable parity (even/odd) if needed
        settings.c_cflag |= parityType.parityValue
        
        // Set stop bit flag
        if sendTwoStopBits {
            settings.c_cflag |= tcflag_t(CSTOPB)
        } else {
            settings.c_cflag &= ~tcflag_t(CSTOPB)
        }
        
        // Set data bits size flag
        settings.c_cflag &= ~tcflag_t(CSIZE)
        settings.c_cflag |= dataBitsSize.flagValue
        
        // Disable input mapping of CR to NL, mapping of NL into CR, and ignoring CR
        settings.c_iflag &= ~tcflag_t(ICRNL | INLCR | IGNCR)
        
        // Set software flow control flags
        let softwareFlowControlFlags = tcflag_t(IXON | IXOFF | IXANY)
        if useSoftwareFlowControl {
            settings.c_iflag |= softwareFlowControlFlags
        } else {
            settings.c_iflag &= ~softwareFlowControlFlags
        }
        
        // Turn on the receiver of the serial port, and ignore modem control lines
        settings.c_cflag |= tcflag_t(CREAD | CLOCAL)
        
        // Turn off canonical mode
        settings.c_lflag &= ~tcflag_t(ICANON | ECHO | ECHOE | ISIG)
        
        
        // Set output processing flag
        if processOutput {
            settings.c_oflag |= tcflag_t(OPOST)
        } else {
            settings.c_oflag &= ~tcflag_t(OPOST)
        }

    }
    
    func writeBytes(from buffer: UnsafeMutablePointer<UInt8>, size: Int) throws -> Int {
        guard let fileDescriptor = fileDescriptor else {
            throw PortError.mustBeOpen
        }
        
        let bytesWritten = write(fileDescriptor, buffer, size)
        return bytesWritten
    }
    
    func writeData(_ data: Data) throws -> Int {
        let size = data.count
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer {
            buffer.deallocate()
        }
        
        data.copyBytes(to: buffer, count: size)
        
        let bytesWritten = try writeBytes(from: buffer, size: size)
        return bytesWritten
    }
    
    func writeString(_ string: String) throws -> Int {
        guard let data = string.data(using: String.Encoding.utf8) else {
            throw PortError.stringsMustBeUTF8
        }
        let bytesWritten = try writeData(data)
        return bytesWritten
    }
    
    public func readBytes(into buffer: UnsafeMutablePointer<UInt8>, size: Int) throws -> Int {
        guard let fileDescriptor = fileDescriptor else {
            throw PortError.mustBeOpen
        }

        var s: stat = stat()
        fstat(fileDescriptor, &s)
        if s.st_nlink != 1 {
            throw PortError.deviceNotConnected
        }

        return read(fileDescriptor, buffer, size)
    }

    public func readData(ofLength length: Int) throws -> Data {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        defer {
            buffer.deallocate()
        }

        let bytesRead = try readBytes(into: buffer, size: length)

        var data : Data

        if bytesRead > 0 {
            data = Data(bytes: buffer, count: bytesRead)
        } else {
            //This is to avoid the case where bytesRead can be negative causing problems allocating the Data buffer
            data = Data(bytes: buffer, count: 0)
        }

        return data
    }

    public func readString(ofLength length: Int) throws -> String {
        var remainingBytesToRead = length
        var result = ""

        while remainingBytesToRead > 0 {
            let data = try readData(ofLength: remainingBytesToRead)

            if let string = String(data: data, encoding: String.Encoding.utf8) {
                result += string
                remainingBytesToRead -= data.count
            } else {
                return result
            }
        }

        return result
    }

    public func readUntilChar(_ terminator: CChar) throws -> String {
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        defer {
            buffer.deallocate()
        }

        while true {
            let bytesRead = try readBytes(into: buffer, size: 1)

            if bytesRead > 0 {
                if ( buffer[0] > 127) {
                    throw PortError.unableToConvertByteToCharacter
                }
                let character = CChar(buffer[0])

                if character == terminator {
                    break
                } else {
                    data.append(buffer, count: 1)
                }
            }
        }

        if let string = String(data: data, encoding: String.Encoding.utf8) {
            return string
        } else {
            throw PortError.stringsMustBeUTF8
        }
    }
    public func readUntilEOF() throws -> String {
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        defer {
            buffer.deallocate()
        }
        while true {
            print(buffer);
            let bytesRead = try readBytes(into: buffer, size: 1)
            print(bytesRead);
            if bytesRead > 0 {
                if ( buffer[0] > 127) {
                    throw PortError.unableToConvertByteToCharacter
                }
                let character = CChar(buffer[0])
                print(character)
                data.append(buffer, count: 1)
            }
            else{
                break
            }
        }
        print(data);
        if let string = String(data: data, encoding: String.Encoding.utf8) {
            return string
        } else {
            throw PortError.stringsMustBeUTF8
        }
    }
    public func readCharReturn() throws -> String {
        let newlineChar = CChar(13) // Newline/Line feed character `\n` is 10
        return try readUntilChar(newlineChar)
    }
    public func readLine() throws -> String {
        let newlineChar = CChar(10) // Newline/Line feed character `\n` is 10
        return try readUntilChar(newlineChar)
    }

    public func readByte() throws -> UInt8 {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)

        defer {
            buffer.deallocate()
        }

        while true {
            let bytesRead = try readBytes(into: buffer, size: 1)

            if bytesRead > 0 {
                return buffer[0]
            }
        }
    }

    public func readChar() throws -> UnicodeScalar {
        let byteRead = try readByte()
        let character = UnicodeScalar(byteRead)
        return character
    }
    
    func openPort(toReceive receive: Bool, andTransmit transmit: Bool) throws {
        closePort()
        guard !deviceInfo.path.isEmpty else {
            throw PortError.invalidPath
        }
        
        guard receive || transmit else {
            throw PortError.mustReceiveOrTransmit
        }

        var readWriteParam : Int32
        
        if receive && transmit {
            readWriteParam = O_RDWR
        } else if receive {
            readWriteParam = O_RDONLY
        } else if transmit {
            readWriteParam = O_WRONLY
        } else {
            fatalError()
        }

        fileDescriptor = open(deviceInfo.path, readWriteParam | O_NOCTTY | O_EXLOCK | O_EVTONLY)
        
        
        // Throw error if open() failed
        if fileDescriptor == PortError.failedToOpen.rawValue {
            throw PortError.failedToOpen
        }
        startMonitoring()
    }

    func startMonitoring() {
        // Define a dispatch source monitoring the folder for additions, deletions, and renamings.
        folderMonitorSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor!,
            eventMask: DispatchSource.FileSystemEvent.write,
            queue: DispatchQueue.global()//DispatchQueue(label: "directorymonitor", attributes: .concurrent)
        )
        // Define the block to call when a file change is detected.
        folderMonitorSource?.setEventHandler {
            do{
                let readCharacter = try self.readCharReturn()
                print(readCharacter)
                if(!self.isNewRead){
                    //readCharacter = try self.readLine()
                }
                NotificationCenter.default.post(name: .SerialReadStream, object: ["received": readCharacter])
            } catch {
                NotificationCenter.default.post(name: .SerialReadStream, object: ["received": "Error: \(error)"])
            }
            
            self.isNewRead = false
        }
        
        // Define a cancel handler to ensure the directory is closed when the source is cancelled.
        folderMonitorSource?.setCancelHandler {
            //self.closePort()
            self.folderMonitorSource = nil
        }
        
        // Start monitoring the directory via the source.
        folderMonitorSource?.resume()
    }
    func stopMonitoring() {
        folderMonitorSource?.cancel()
    }
    
    public func closePort() {
        if let fileDescriptor = fileDescriptor {
            stopMonitoring()
            close(fileDescriptor)
        }
        isNewRead = true
        fileDescriptor = nil
    }
}
