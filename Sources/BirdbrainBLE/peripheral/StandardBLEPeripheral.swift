//
// Created by Chris Bartley on 4/14/20.
//

import Foundation
import os
import CoreBluetooth

open class StandardBLEPeripheral: NSObject, BLEPeripheral {

   //MARK: - Public properties

   public var uuid: UUID {
      peripheral.identifier
   }

   open var name: String {
      if let name = advertisementData[CBAdvertisementDataLocalNameKey] {
         return String(describing: name)
      }
      return uuid.uuidString
   }

   public var delegate: BLEPeripheralDelegate?

   //MARK: - Private properties

   private let serviceAndCharacteristicUUIDs: BLEPeripheralUUIDs
   private let peripheral: CBPeripheral
   private let advertisementData: [String : Any]

   //MARK: - Initializers

   public init(serviceAndCharacteristicUUIDs: BLEPeripheralUUIDs, peripheral: CBPeripheral, advertisementData: [String : Any]) {
      self.serviceAndCharacteristicUUIDs = serviceAndCharacteristicUUIDs
      self.peripheral = peripheral
      self.advertisementData = advertisementData
      super.init()

      self.peripheral.delegate = self
   }

   //MARK: - Open methods

   open func isPropertySupported(property: CBCharacteristicProperties, byCharacteristic uuid: CBUUID) -> Bool {
      if let characteristic = findCharacteristic(havingUUID: uuid) {
         return characteristic.properties.contains(property)
      }
      else {
         os_log("isPropertySupported: unknown characteristic [%s]", log: OSLog.standardBLEPeripheral, type: .default, uuid.uuidString)
      }
      return false
   }

   public func setNotifyEnabled(onCharacteristic uuid: CBUUID) -> Bool {
      return setNotifyEnabled(true, onCharacteristic: uuid)
   }

   public func setNotifyDisabled(onCharacteristic uuid: CBUUID) -> Bool {
      return setNotifyEnabled(false, onCharacteristic: uuid)
   }

   open func read(fromCharacteristic uuid: CBUUID) -> Bool {
      if let characteristic = findCharacteristic(havingUUID: uuid) {
         if characteristic.properties.contains(.read) {
            peripheral.readValue(for: characteristic)
            return true
         }
         else {
            os_log("read: characteristic [%s] does not support reads", log: OSLog.standardBLEPeripheral, type: .default, uuid.uuidString)
         }
      }
      return false
   }

   public func writeWithResponse(bytes: [UInt8], toCharacteristic uuid: CBUUID) -> Bool {
      return writeWithResponse(data: Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count), toCharacteristic: uuid)
   }

   public func writeWithResponse(data: Data, toCharacteristic uuid: CBUUID) -> Bool {
      return write(data: data, toCharacteristic: uuid, writeType: .withResponse)
   }

   public func writeWithoutResponse(bytes: [UInt8], toCharacteristic uuid: CBUUID) -> Bool {
      return writeWithoutResponse(data: Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count), toCharacteristic: uuid)
   }

   public func writeWithoutResponse(data: Data, toCharacteristic uuid: CBUUID) -> Bool {
      return write(data: data, toCharacteristic: uuid, writeType: .withoutResponse)
   }

   //MARK: - Private methods

   private func findCharacteristic(havingUUID uuid: CBUUID) -> CBCharacteristic? {
      if let peripheralServices = peripheral.services {
         for service in peripheralServices {
            if let characteristics = service.characteristics {
               for characteristic in characteristics {
                  if uuid == characteristic.uuid {
                     return characteristic
                  }
               }
               os_log("findCharacteristic: characteristic [%s] not found!", log: OSLog.standardBLEPeripheral, type: .default, uuid.uuidString)
            }
            else {
               os_log("findCharacteristic: no characteristics found for service [%s]", log: OSLog.standardBLEPeripheral, type: .default, service.uuid.uuidString)
            }
         }
      }
      else {
         os_log("findCharacteristic: no services found", log: OSLog.standardBLEPeripheral, type: .default)
      }
      return nil
   }

   private func setNotifyEnabled(_ isEnabled: Bool, onCharacteristic uuid: CBUUID) -> Bool {
      if let characteristic = findCharacteristic(havingUUID: uuid) {
         if characteristic.properties.contains(.notify) ||
            characteristic.properties.contains(.indicate) {
            peripheral.setNotifyValue(isEnabled, for: characteristic)
            return true
         }
         else {
            os_log("setNotifyEnabled: characteristic [%s] does not support notify or indicate", log: OSLog.standardBLEPeripheral, type: .default, uuid.uuidString)
         }
      }
      return false
   }

   private func write(data: Data, toCharacteristic uuid: CBUUID, writeType: CBCharacteristicWriteType) -> Bool {
      if let characteristic = findCharacteristic(havingUUID: uuid) {
         if (writeType == .withResponse && characteristic.properties.contains(.write)) ||
            (writeType == .withoutResponse && characteristic.properties.contains(.writeWithoutResponse)) {
            peripheral.writeValue(data, for: characteristic, type: writeType)
            return true
         }
         else {
            os_log("setNotifyEnabled: characteristic [%s] does not support writeType [%s]", log: OSLog.standardBLEPeripheral, type: .default, uuid.uuidString, String(describing: writeType))
         }
      }
      return false
   }
}

//MARK: - CBPeripheralDelegate

extension StandardBLEPeripheral: CBPeripheralDelegate {
   public func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
      os_log("CBPeripheralDelegate.peripheralDidUpdateName unimplemented!", log: OSLog.standardBLEPeripheral, type: .error)
   }

   public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
      os_log("CBPeripheralDelegate.didModifyServices unimplemented!", log: OSLog.standardBLEPeripheral, type: .error)
   }

   public func peripheralDidUpdateRSSI(_ peripheral: CBPeripheral, error: Error?) {
      os_log("CBPeripheralDelegate.peripheralDidUpdateRSSI unimplemented!", log: OSLog.standardBLEPeripheral, type: .error)
   }

   public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
      os_log("CBPeripheralDelegate.didReadRSSI unimplemented!", log: OSLog.standardBLEPeripheral, type: .error)
   }

   public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
      delegate?.blePeripheral(self, didUpdateValueFor: characteristic.uuid, value: characteristic.value, error: error)
   }

   public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
      delegate?.blePeripheral(self, didWriteValueFor: characteristic.uuid, error: error)
   }

   public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
      delegate?.blePeripheral(self, didUpdateNotificationStateFor: characteristic.uuid, isNotifying: characteristic.isNotifying, error: error)
   }

   public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
      os_log("CBPeripheralDelegate.didUpdateValueForDescriptor unimplemented!", log: OSLog.standardBLEPeripheral, type: .error)
   }

   public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
      os_log("CBPeripheralDelegate.didWriteValueForDescriptor unimplemented!", log: OSLog.standardBLEPeripheral, type: .error)
   }

   public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
      os_log("CBPeripheralDelegate.peripheralIsReady unimplemented!", log: OSLog.standardBLEPeripheral, type: .error)
   }

   public func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
      os_log("CBPeripheralDelegate.didOpenChannel unimplemented!", log: OSLog.standardBLEPeripheral, type: .error)
   }

   // this should never be called, because the peripheral will already be connected and fully discovered before creation of this instance
   public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
      os_log("CBPeripheralDelegate.didDiscoverServices unimplemented, should have been handled by the central manager", log: OSLog.standardBLEPeripheral, type: .error)
   }

   // this should never be called, because the peripheral will already be connected and fully discovered before creation of this instance
   public func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
      os_log("CBPeripheralDelegate.didDiscoverIncludedServicesFor unimplemented, should have been handled by the central manager", log: OSLog.standardBLEPeripheral, type: .error)
   }

   // this should never be called, because the peripheral will already be connected and fully discovered before creation of this instance
   public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
      os_log("CBPeripheralDelegate.didDiscoverCharacteristicsFor unimplemented, should have been handled by the central manager", log: OSLog.standardBLEPeripheral, type: .error)
   }

   // this should never be called, because the peripheral will already be connected and fully discovered before creation of this instance
   public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
      os_log("CBPeripheralDelegate.didDiscoverDescriptorsFor unimplemented, should have been handled by the central manager", log: OSLog.standardBLEPeripheral, type: .error)
   }
}