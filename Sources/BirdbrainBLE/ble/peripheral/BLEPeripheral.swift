//
// Created by Chris Bartley on 4/14/20.
//

import Foundation
import CoreBluetooth

public protocol BLEPeripheral: class {
   var uuid: UUID { get }

   /// A name for this peripheral, or `nil` if no name is available. Subclasses are free to override and define however
   /// they see fit.
   var name: String? { get }

   /// The BLE advertised name, if available; returns `nil` otherwise.
   var advertisedName: String? { get }

   var delegate: BLEPeripheralDelegate? { get set }

   func isPropertySupported(property: CBCharacteristicProperties, byCharacteristic uuid: CBUUID) -> Bool

   func setNotifyEnabled(onCharacteristic uuid: CBUUID) -> Bool
   func setNotifyDisabled(onCharacteristic uuid: CBUUID) -> Bool

   func read(fromCharacteristic uuid: CBUUID) -> Bool

   /// Tries to write the given data to the specified characteristic.  Returns true if the characteristic exists and
   /// supports writing with response; false otherwise.
   func writeWithResponse(bytes: [UInt8], toCharacteristic uuid: CBUUID) -> Bool
   func writeWithResponse(data: Data, toCharacteristic uuid: CBUUID) -> Bool

   /// Tries to write the given data to the specified characteristic.  Returns true if the characteristic exists and
   /// supports writing without response; false otherwise.
   func writeWithoutResponse(bytes: [UInt8], toCharacteristic uuid: CBUUID) -> Bool
   func writeWithoutResponse(data: Data, toCharacteristic uuid: CBUUID) -> Bool

   /// Returns the maximum amount of data, in bytes, you can send to a characteristic in a single write-with-response.
   func maximumWriteWithResponseDataLength() -> Int

   /// Returns the maximum amount of data, in bytes, you can send to a characteristic in a single write-without-response.
   func maximumWriteWithoutResponseDataLength() -> Int
}