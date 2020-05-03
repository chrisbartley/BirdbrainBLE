//
// Created by Chris Bartley on 4/14/20.
//

import Foundation
import CoreBluetooth

public protocol BLEPeripheral: class {
   var uuid: UUID { get }

   var name: String { get }

   var delegate: BLEPeripheralDelegate? { get set }

   func isPropertySupported(property: CBCharacteristicProperties, byCharacteristic uuid: CBUUID) -> Bool

   func setNotifyEnabled(onCharacteristic uuid: CBUUID) -> Bool
   func setNotifyDisabled(onCharacteristic uuid: CBUUID) -> Bool

   func read(fromCharacteristic uuid: CBUUID) -> Bool

   // Tries to write the given data to the specified characteristic.  Returns true if the characteristic exists and
   // supports writing with response; false otherwise.
   func writeWithResponse(bytes: [UInt8], toCharacteristic uuid: CBUUID) -> Bool
   func writeWithResponse(data: Data, toCharacteristic uuid: CBUUID) -> Bool

   // Tries to write the given data to the specified characteristic.  Returns true if the characteristic exists and
   // supports writing without response; false otherwise.
   func writeWithoutResponse(bytes: [UInt8], toCharacteristic uuid: CBUUID) -> Bool
   func writeWithoutResponse(data: Data, toCharacteristic uuid: CBUUID) -> Bool
}