//
// Created by Chris Bartley on 4/14/20.
//

import Foundation
import CoreBluetooth

public protocol BLEPeripheralDelegate {
   func blePeripheral(_ peripheral: BLEPeripheral, didUpdateNotificationStateFor characteristicUUID: CBUUID, isNotifying: Bool, error: Error?)

   func blePeripheral(_ peripheral: BLEPeripheral, didUpdateValueFor characteristicUUID: CBUUID, value: Data?, error: Error?)

   func blePeripheral(_ peripheral: BLEPeripheral, didWriteValueFor characteristicUUID: CBUUID, error: Error?)

   func blePeripheral(_ peripheral: BLEPeripheral, isReadyToSendWriteWithoutResponse: Bool)
}

public extension BLEPeripheralDelegate {
   func blePeripheral(_ peripheral: BLEPeripheral, didUpdateNotificationStateFor characteristicUUID: CBUUID, isNotifying: Bool, error: Error?) {}

   func blePeripheral(_ peripheral: BLEPeripheral, didUpdateValueFor characteristicUUID: CBUUID, value: Data?, error: Error?) {}

   func blePeripheral(_ peripheral: BLEPeripheral, didWriteValueFor characteristicUUID: CBUUID, error: Error?) {}

   func blePeripheral(_ peripheral: BLEPeripheral, isReadyToSendWriteWithoutResponse: Bool) {}
}