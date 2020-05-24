//
// Created by Chris Bartley on 4/26/20.
//

import Foundation
import os
import CoreBluetooth

fileprivate extension OSLog {
   static let log = OSLog(category: "BaseUARTDevice")
}

open class BaseUARTDevice: UARTDevice {

   static private let startNotificationsCommand: [UInt8] = [0x62, 0x67]
   static private let stopNotificationsCommand: [UInt8] = [0x62, 0x73]
   static private let txUUID = UARTDeviceServicesAndCharacteristics.txUUID
   static private let rxUUID = UARTDeviceServicesAndCharacteristics.rxUUID

   //MARK: - Public Properties

   public var uuid: UUID {
      return blePeripheral.uuid
   }

   public private(set) var advertisementSignature: AdvertisementSignature?

   public var delegate: UARTDeviceDelegate?

   //MARK: - Private Properties

   private let blePeripheral: BLEPeripheral

   public private(set) var rawState: Data?

   //MARK: - Initializers

   required public init(blePeripheral: BLEPeripheral) {
      advertisementSignature = AdvertisementSignature(advertisedName: blePeripheral.name)
      self.blePeripheral = blePeripheral
      self.blePeripheral.delegate = self
   }

   //MARK: - Public Methods

   public func startStateChangeNotifications() -> Bool {
      return blePeripheral.setNotifyEnabled(onCharacteristic: BaseUARTDevice.rxUUID) &&
             blePeripheral.writeWithoutResponse(bytes: BaseUARTDevice.startNotificationsCommand, toCharacteristic: BaseUARTDevice.txUUID)
   }

   public func stopStateChangeNotifications() -> Bool {
      return blePeripheral.writeWithoutResponse(bytes: BaseUARTDevice.stopNotificationsCommand, toCharacteristic: BaseUARTDevice.txUUID) &&
             blePeripheral.setNotifyDisabled(onCharacteristic: BaseUARTDevice.rxUUID)
   }

   public func writeWithResponse(bytes: [UInt8]) {
      let _ = blePeripheral.writeWithResponse(bytes: bytes, toCharacteristic: BaseUARTDevice.txUUID)
   }

   public func writeWithResponse(data: Data) {
      let _ = blePeripheral.writeWithResponse(data: data, toCharacteristic: BaseUARTDevice.txUUID)
   }

   public func writeWithoutResponse(bytes: [UInt8]) {
      let _ = blePeripheral.writeWithoutResponse(bytes: bytes, toCharacteristic: BaseUARTDevice.txUUID)
   }

   public func writeWithoutResponse(data: Data) {
      let _ = blePeripheral.writeWithoutResponse(data: data, toCharacteristic: BaseUARTDevice.txUUID)
   }
}

extension BaseUARTDevice: BLEPeripheralDelegate {
   public func blePeripheral(_ peripheral: BLEPeripheral, didUpdateNotificationStateFor characteristicUUID: CBUUID, isNotifying: Bool, error: Error?) {
      if let _ = error {
         os_log("BLEPeripheralDelegate.didUpdateNotificationStateFor: uuid=%s|isNotifying=%{public}s|error=%s", log: OSLog.log, type: .error, characteristicUUID.uuidString, isNotifying, String(describing: error))
      }
      delegate?.uartDevice(self, isSendingStateChangeNotifications: isNotifying)
   }

   public func blePeripheral(_ peripheral: BLEPeripheral, didUpdateValueFor characteristicUUID: CBUUID, value: Data?, error: Error?) {
      if let error = error {
         os_log("BLEPeripheralDelegate.didUpdateValueFor: uuid=%s|error=%s", log: OSLog.log, type: .error, characteristicUUID.uuidString, String(describing: error))
         delegate?.uartDevice(self, errorGettingState: error)
      }
      else {
         if characteristicUUID == BaseUARTDevice.rxUUID, let value = value {
            rawState = value
            delegate?.uartDevice(self, newState: value)
         }
         else {
            os_log("BLEPeripheralDelegate.didUpdateValueFor (unexpected characteristic): uuid=%s|value=%s", log: OSLog.log, type: .error, characteristicUUID.uuidString, String(describing: value))
         }
      }
   }

   public func blePeripheral(_ peripheral: BLEPeripheral, didWriteValueFor characteristicUUID: CBUUID, error: Error?) {
      os_log("BLEPeripheralDelegate.didWriteValueFor: uuid=%s|error=%s", log: OSLog.log, type: .error, characteristicUUID.uuidString, String(describing: error))
   }
}