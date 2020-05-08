//
// Created by Chris Bartley on 4/24/20.
//

import Foundation
import os
import CoreBluetooth

fileprivate extension OSLog {
   static let log = OSLog(category: "UARTDeviceManager")
}

public class UARTDeviceManager<DeviceType: ManageableUARTDevice> {

   //MARK: - Public Properties

   public var delegate: UARTDeviceManagerDelegate?

   //MARK: - Private Properties

   private let bleCentralManager: StandardBLECentralManager

   private var devices = [UUID : DeviceType]()

   private let scanFilter: UARTDeviceScanFilter

   //MARK: - Initializers

   convenience public init(scanFilter: UARTDeviceScanFilter, delegate: UARTDeviceManagerDelegate) {
      self.init(scanFilter: scanFilter)
      self.delegate = delegate
   }

   public init(scanFilter: UARTDeviceScanFilter) {
      self.scanFilter = scanFilter
      bleCentralManager = StandardBLECentralManager(servicesAndCharacteristics: UARTDeviceServicesAndCharacteristics.instance)
      bleCentralManager.delegate = self
   }

   //MARK: - Public Methods

   public func startScanning() -> Bool {
      return bleCentralManager.startScanning(timeoutSecs: -1)
   }

   public func stopScanning() -> Bool {
      return bleCentralManager.stopScanning()
   }

   public func connectToDevice(havingUUID uuid: UUID) -> Bool {
      return bleCentralManager.connectToPeripheral(havingUUID: uuid)
   }

   public func disconnectFromDevice(havingUUID uuid: UUID) -> Bool {
      return bleCentralManager.disconnectFromPeripheral(havingUUID: uuid)
   }

   public func getDevice(uuid: UUID) -> DeviceType? {
      return devices[uuid]
   }
}

extension UARTDeviceManager: BLECentralManagerDelegate {
   public func didUpdateState(to state: CBManagerState) {
      os_log("didUpdateState(%{public}s)", log: OSLog.log, type: .debug, String(describing: state))
      switch state {
         case .poweredOn:
            delegate?.didUpdateState(to: .enabled)
         case .poweredOff:
            delegate?.didUpdateState(to: .disabled)
         case .unauthorized, .unknown, .resetting, .unsupported:
            delegate?.didUpdateState(to: .error)
         @unknown default:
            os_log("A previously unknown central manager state occurred. CBManagerState '%{public}s' not yet handled", log: OSLog.log, type: .error, String(describing: state))
            delegate?.didUpdateState(to: .error)
      }
   }

   public func didPowerOn() {
      // nothing to do, handled by didUpdateState()
   }

   public func didPowerOff() {
      // nothing to do, handled by didUpdateState()
   }

   public func didScanTimeout() {
      os_log("BLECentralManagerDelegate: Scan should never timeout", log: OSLog.log, type: .error)
   }

   public func didDiscoverPeripheral(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber) {
      if scanFilter.isOfType(uuid: uuid, advertisementData: advertisementData, rssi: rssi) {
         let nameAndAdvertisedName = UARTDeviceNameGenerator.instance.generateNameFrom(advertisementData: advertisementData)
         delegate?.didDiscover(uuid: uuid,
                               name: nameAndAdvertisedName.name,
                               advertisedName: nameAndAdvertisedName.advertisedName,
                               advertisementData: advertisementData,
                               rssi: rssi)
      }
      else {
         os_log("BLECentralManagerDelegate: Ignoring discovery of device which doesn't pass scan filter: [uuid=%s]", log: OSLog.log, type: .debug, uuid.uuidString)
      }
   }

   public func didRediscoverPeripheral(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber) {
      if scanFilter.isOfType(uuid: uuid, advertisementData: advertisementData, rssi: rssi) {
         let nameAndAdvertisedName = UARTDeviceNameGenerator.instance.generateNameFrom(advertisementData: advertisementData)
         delegate?.didRediscover(uuid: uuid,
                                 name: nameAndAdvertisedName.name,
                                 advertisedName: nameAndAdvertisedName.advertisedName,
                                 advertisementData: advertisementData,
                                 rssi: rssi)
      }
      else {
         os_log("BLECentralManagerDelegate: Ignoring rediscovery of device which doesn't pass scan filter: [uuid=%s]", log: OSLog.log, type: .debug, uuid.uuidString)
      }
   }

   public func didConnectToPeripheral(peripheral: BLEPeripheral) {
      devices[peripheral.uuid] = DeviceType(blePeripheral: peripheral)
      delegate?.didConnectTo(uuid: peripheral.uuid)
   }

   public func didDisconnectFromPeripheral(uuid: UUID, error: Error?) {
      if let _ = devices.removeValue(forKey: uuid) {
         delegate?.didDisconnectFrom(uuid: uuid, error: error)
      }
   }

   public func didFailToConnectToPeripheral(uuid: UUID, error: Error?) {
      delegate?.didFailToConnectTo(uuid: uuid, error: error)
   }
}