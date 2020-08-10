//
// Created by Chris Bartley on 4/9/20.
//

import Foundation
import os
import CoreBluetooth

fileprivate extension OSLog {
   static let log = OSLog(category: "StandardBLECentralManager")
}

fileprivate enum BLEPeripheralState: String {
   case disconnected = "Disconnected"
   case connecting = "Connecting"
   case connectedAndDiscovering = "Connected and Discovering"
   case connectedAndDiscovered = "Connected and Discovered"
   case disconnecting = "Disconnecting"
}

public class StandardBLECentralManager: NSObject, BLECentralManager {

   static public let defaultAssumeDisappearanceTimeInterval: TimeInterval = 3.0

   //MARK: - Public Properties

   public weak var delegate: BLECentralManagerDelegate?

   //MARK: - Private Properties

   private var centralManager: CBCentralManager!
   private let servicesAndCharacteristics: SupportedServicesAndCharacteristics
   private var peripheralInfoByUUID = [UUID : (peripheral: CBPeripheral,
                                               blePeripheral: StandardBLEPeripheral?,
                                               advertisementData: [String : Any],
                                               lastSeen: Date, // motivated by https://fivepackcreative.com/3-things-know-ios-bluetooth-coding/
                                               state: BLEPeripheralState)]()

   //MARK: - Initializers

   public convenience init(servicesAndCharacteristics: SupportedServicesAndCharacteristics,
                           delegate: BLECentralManagerDelegate) {
      self.init(servicesAndCharacteristics: servicesAndCharacteristics)
      self.delegate = delegate
   }

   public init(servicesAndCharacteristics: SupportedServicesAndCharacteristics) {
      self.servicesAndCharacteristics = servicesAndCharacteristics
      super.init();
      self.centralManager = CBCentralManager(delegate: self, queue: nil)
   }

   //MARK: - Public Methods

   // Note that Apple's docs say this about CBCentralManagerScanOptionAllowDuplicatesKey: "Disabling this filtering
   // [i.e. setting to true] can have an adverse effect on battery life; use it only if necessary."  Also, I read
   // elsewhere (https://stackoverflow.com/a/44515562/703200) that allowing duplicates will prevent background scans.

   /// Starts scanning, with a timeout of `timeoutSecs`.  Assumes disappearance of peripherals after
   /// `StandardBLECentralManager.defaultAssumeDisappearanceTimeInterval` seconds.
   ///
   /// Warning: this implmentation assumes and requires that a peripheral has an advertising name for it to be
   /// "discovered". That is, a discovery message from CoreBluetooth for a UUID we've not seen before which doesn't
   /// contain an advertising name will be ignored.
   ///
   /// - Parameter timeoutSecs: number of seconds to scan until timing out
   /// - Returns: true if scanning was successfully initiated; false otherwise.
   @discardableResult
   public func startScanning(timeoutSecs: TimeInterval) -> Bool {
      return startScanning(timeoutSecs: timeoutSecs,
                           assumeDisappearanceAfter: StandardBLECentralManager.defaultAssumeDisappearanceTimeInterval,
                           allowDuplicates: true)
   }

   /// Starts scanning, with a timeout of `timeoutSecs`, and assumes disappearance after the given `assumeDisappearanceAfter`
   /// TimeInterval (or `StandardBLECentralManager.defaultAssumeDisappearanceTimeInterval` if not provided).
   ///
   /// Warning: this implmentation assumes and requires that a peripheral has an advertising name for it to be
   /// "discovered". That is, a discovery message from CoreBluetooth for a UUID we've not seen before which doesn't
   /// contain an advertising name will be ignored.
   ///
   /// - Parameters:
   ///   - timeoutSecs: number of seconds to scan until timing out
   ///   - assumeDisappearanceAfter: TimeInterval before considering a peripheral as having disappeared
   ///   - allowDuplicates: whether to allow duplicate scan discoveries, defaults to true
   /// - Returns:
   @discardableResult
   public func startScanning(timeoutSecs: TimeInterval,
                             assumeDisappearanceAfter: TimeInterval = StandardBLECentralManager.defaultAssumeDisappearanceTimeInterval,
                             allowDuplicates: Bool = true) -> Bool {

      // make sure BLE is powered on
      if centralManager.state != .poweredOn {
         os_log("BLE powered off, cannot scan", log: OSLog.log, type: .default)
         return false
      }

      // make sure we're not already scanning
      if centralManager.isScanning {
         os_log("Already scanning, nothing to do", log: OSLog.log, type: .debug)
         return false
      }

      os_log("Scanning started", log: OSLog.log, type: .debug)

      if timeoutSecs > 0 {
         Timer.scheduledTimer(timeInterval: timeoutSecs, target: self, selector: #selector(scanTimeout), userInfo: nil, repeats: false)
      }

      // look for disappeared peripherals every half second
      Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
         if self.centralManager.state != .poweredOn || !self.centralManager.isScanning {
            timer.invalidate()
         }
         else {
            for (uuid, peripheralInfo) in self.peripheralInfoByUUID {
               // if this peripheral isn't connected AND hasn't been seen recently, then flag it as disappeared
               if peripheralInfo.state == .disconnected &&
                  abs(peripheralInfo.lastSeen.timeIntervalSinceNow) >= abs(assumeDisappearanceAfter) {
                  os_log("Flagging peripheral %s as disappeared", log: OSLog.log, type: .debug, uuid.uuidString)
                  self.peripheralInfoByUUID.removeValue(forKey: uuid)
                  self.delegate?.didPeripheralDisappear(uuid: uuid)
               }
            }
         }
      }

      let options = [CBCentralManagerScanOptionAllowDuplicatesKey : allowDuplicates]
      centralManager.scanForPeripherals(withServices: servicesAndCharacteristics.serviceUUIDs, options: options)

      return true
   }

   @discardableResult
   public func stopScanning() -> Bool {
      if centralManager.isScanning {
         centralManager.stopScan()

         os_log("Scanning stopped", log: OSLog.log, type: .debug)
         return true
      }
      return false
   }

   @discardableResult
   public func connectToPeripheral(havingUUID uuid: UUID) -> Bool {
      // make sure BLE is powered on
      if centralManager.state != .poweredOn {
         os_log("BLE powered off, cannot connect", log: OSLog.log, type: .default)
         return false
      }

      if var peripheralInfo = peripheralInfoByUUID[uuid] {
         if peripheralInfo.state == .disconnected {
            os_log("connectToPeripheral(%s): attempting connection, state=[%{public}s|%{public}s]", log: OSLog.log, type: .info,
                   uuid.uuidString,
                   String(describing: peripheralInfo.state),
                   String(describing: peripheralInfo.peripheral.state))

            // update state
            peripheralInfo.state = .connecting
            peripheralInfoByUUID[uuid] = peripheralInfo

            let options = [CBConnectPeripheralOptionNotifyOnDisconnectionKey : NSNumber(value: true)]
            centralManager.connect(peripheralInfo.peripheral, options: options)
            return true
         }
         else {
            os_log("connectToPeripheral(%s): not attempting connection since state is [%{public}s]", log: OSLog.log, type: .info,
                   uuid.uuidString,
                   String(describing: peripheralInfo.state))
         }
      }
      else {
         os_log("connectToPeripheral(%s): unknown peripheral, cannot connect", log: OSLog.log, type: .default, uuid.uuidString)
      }

      return false
   }

   @discardableResult
   public func disconnectFromPeripheral(havingUUID uuid: UUID) -> Bool {
      // make sure BLE is powered on
      if centralManager.state != .poweredOn {
         os_log("BLE powered off, cannot disconnect", log: OSLog.log, type: .default)
         return false
      }

      if var peripheralInfo = peripheralInfoByUUID[uuid] {
         if peripheralInfo.state == .connecting || peripheralInfo.state == .connectedAndDiscovering || peripheralInfo.state == .connectedAndDiscovered {
            os_log("disconnectFromPeripheral(%s): attempting disconnection, state=[%{public}s|%{public}s]", log: OSLog.log, type: .info,
                   uuid.uuidString,
                   String(describing: peripheralInfo.state),
                   String(describing: peripheralInfo.peripheral.state))

            // update state
            peripheralInfo.state = .disconnecting
            peripheralInfoByUUID[uuid] = peripheralInfo

            centralManager.cancelPeripheralConnection(peripheralInfo.peripheral)
            return true
         }
         else {
            os_log("disconnectFromPeripheral(%s): not attempting disconnection since state is [%{public}s]", log: OSLog.log, type: .info, uuid.uuidString, String(describing: peripheralInfo.state))
         }
      }
      else {
         os_log("disconnectFromPeripheral(%s): unknown peripheral, cannot disconnect", log: OSLog.log, type: .default, uuid.uuidString)
      }

      return false
   }

   //MARK: - Private Methods

   @objc private func scanTimeout() {
      if centralManager.isScanning {
         centralManager.stopScan()
         os_log("Scanning stopped due to timeout", log: OSLog.log, type: .debug)

         delegate?.didScanTimeout()
      }
   }
}

//MARK: - CBCentralManagerDelegate

extension StandardBLECentralManager: CBCentralManagerDelegate {
   public func centralManagerDidUpdateState(_ central: CBCentralManager) {

      delegate?.didUpdateState(to: central.state)

      switch central.state {
         case .poweredOff:
            delegate?.didPowerOff()
         case .poweredOn:
            delegate?.didPowerOn()
         case .unauthorized:
            // TODO: do something better here...
            if #available(iOS 13.0, *) {
               switch central.authorization {
                  case .denied:
                     os_log("CBCentralManagerDelegate: Bluetooth usage denied", log: OSLog.log, type: .error)
                  case .restricted:
                     os_log("CBCentralManagerDelegate: Bluetooth usage is restricted", log: OSLog.log, type: .error)
                  default:
                     os_log("CBCentralManagerDelegate: Unexpected authorization", log: OSLog.log, type: .error)
               }
            }
            else {
               os_log("CBCentralManagerDelegate: Bluetooth usage not authorized", log: OSLog.log, type: .error)
            }
         case .unknown, .resetting, .unsupported:
            // TODO
            os_log("CBCentralManagerDelegate: CBManagerState '%{public}s' not yet handled", log: OSLog.log, type: .error, String(describing: central.state))

         @unknown default:
            os_log("CBCentralManagerDelegate: Unexpected CBManagerState '%{public}s' not yet handled", log: OSLog.log, type: .error, String(describing: central.state))
      }
   }

   public func centralManager(_ central: CBCentralManager,
                              didDiscover peripheral: CBPeripheral,
                              advertisementData: [String : Any],
                              rssi: NSNumber) {

      let uuid = peripheral.identifier

      // determine whether we've seen this one before and add/update accordingingly
      if var peripheralInfo = peripheralInfoByUUID[uuid] {
         // we've seen this one before, so simply update lastSeen and advertisementData.  We'll update advertisementData
         // by merging in the new data rather than simply replacing.  This lets us keep track of everything we've ever
         // learned about the peripheral.
         peripheralInfo.lastSeen = Date()
         peripheralInfo.advertisementData = peripheralInfo.advertisementData.merging(advertisementData) { (_, new) in new}
         peripheralInfoByUUID[uuid] = peripheralInfo

         // os_log("CBCentralManagerDelegate.didDiscover: Re-discovered peripheral [%s] total=%d state=[%{public}s|%{public}s]", log: OSLog.log, type: .debug,
         //        uuid.uuidString,
         //        peripheralInfoByUUID.count,
         //        String(describing: peripheralInfo.state),
         //        String(describing: peripheralInfo.peripheral.state))

         // when notifying the delegate, send the *merged* advertisementData, rather than the one we just received, so
         // that we'll be sure to include everything we've ever known about the peripheral (for our purposes, this
         // ensures that we always include the (last-known) advertising name).
         delegate?.didRediscoverPeripheral(uuid: uuid, advertisementData: peripheralInfo.advertisementData, rssi: rssi)
      }
      else {
         // This one is new, but first check whether it's connectable AND that the advertising name is included in the
         // advertisement data before we add it to our collection and notify the delegate.
         if let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber,
            isConnectable == 1,
            let _ = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            // add it to the peripheralInfo collection
            peripheralInfoByUUID[uuid] = (peripheral: peripheral,
                                          blePeripheral: nil,
                                          advertisementData: advertisementData,
                                          lastSeen: Date(),
                                          state: .disconnected)

            // notifiy the delegate of the new peripheral
            os_log("CBCentralManagerDelegate.didDiscover: Discovered peripheral [%s] total=%d state=[%{public}s|%{public}s]", log: OSLog.log, type: .debug,
                   uuid.uuidString,
                   peripheralInfoByUUID.count,
                   String(describing: BLEPeripheralState.disconnected),
                   String(describing: peripheral.state))
            delegate?.didDiscoverPeripheral(uuid: uuid, advertisementData: advertisementData, rssi: rssi)
         }
         else {
            os_log("CBCentralManagerDelegate.didDiscover: Ignoring non-connectable discovery of peripheral [%s]", log: OSLog.log, type: .debug, uuid.uuidString)
         }
      }
   }

   public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
      let uuid = peripheral.identifier

      if var peripheralInfo = peripheralInfoByUUID[uuid] {
         // make sure this isn't a duplicate didConnect notification (I was seeing these on MacOS, at least)
         if peripheralInfo.state == .connecting {
            os_log("CBCentralManagerDelegate.didConnect: to peripheral [%s] state=[%{public}s|%{public}s], now discovering services...", log: OSLog.log, type: .info,
                   uuid.uuidString,
                   String(describing: peripheralInfo.state),
                   String(describing: peripheralInfo.peripheral.state))

            // update state
            peripheralInfo.lastSeen = Date()
            peripheralInfo.state = .connectedAndDiscovering
            peripheralInfoByUUID[uuid] = peripheralInfo

            // set the peripheral's delegate to self so we can get the service and characteristic discovery messages
            peripheral.delegate = self

            // discover services
            peripheral.discoverServices(servicesAndCharacteristics.serviceUUIDs)
         }
         else {
            os_log("CBCentralManagerDelegate.didConnect: ignoring duplicate didConnect for peripheral [%s] state=[%{public}s|%{public}s]", log: OSLog.log, type: .info,
                   uuid.uuidString,
                   String(describing: peripheralInfo.state),
                   String(describing: peripheralInfo.peripheral.state))
         }
      }
      else {
         os_log("CBCentralManagerDelegate.didConnect: ignoring for undiscovered peripheral [%s]", log: OSLog.log, type: .error, uuid.uuidString)
      }
   }

   public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
      let uuid = peripheral.identifier

      if var peripheralInfo = peripheralInfoByUUID[uuid] {
         os_log("CBCentralManagerDelegate.didDisconnectPeripheral: for peripheral [%s] state=[%{public}s|%{public}s]", log: OSLog.log, type: .info,
                uuid.uuidString,
                String(describing: peripheralInfo.state),
                String(describing: peripheralInfo.peripheral.state))

         // update state
         peripheralInfo.lastSeen = Date()
         peripheralInfo.state = .disconnected
         peripheralInfo.blePeripheral?.delegate = nil
         peripheralInfo.blePeripheral = nil
         peripheralInfoByUUID[uuid] = peripheralInfo

         delegate?.didDisconnectFromPeripheral(uuid: uuid, error: error)
      }
      else {
         os_log("CBCentralManagerDelegate.didDisconnectPeripheral: ignoring for undiscovered peripheral [%s]", log: OSLog.log, type: .error, uuid.uuidString)
      }
   }

   public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
      let uuid = peripheral.identifier

      if var peripheralInfo = peripheralInfoByUUID[uuid] {
         os_log("CBCentralManagerDelegate: didFailToConnect for peripheral [%s]: state=[%{public}s|%{public}s]", log: OSLog.log, type: .info,
                uuid.uuidString,
                String(describing: peripheralInfo.state),
                String(describing: peripheralInfo.peripheral.state))

         // update state
         peripheralInfo.lastSeen = Date()
         peripheralInfo.state = .disconnected
         peripheralInfo.blePeripheral?.delegate = nil
         peripheralInfo.blePeripheral = nil
         peripheralInfoByUUID[uuid] = peripheralInfo

         delegate?.didFailToConnectToPeripheral(uuid: uuid, error: error)
      }
      else {
         os_log("CBCentralManagerDelegate.didFailToConnect: ignoring for undiscovered peripheral [%s]", log: OSLog.log, type: .error, uuid.uuidString)
      }
   }
}

//MARK: - CBPeripheralDelegate

extension StandardBLECentralManager: CBPeripheralDelegate {
   public func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
      os_log("CBPeripheralDelegate.peripheralDidUpdateName unimplemented!", log: OSLog.log, type: .error)
   }

   public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
      os_log("CBPeripheralDelegate.didModifyServices unimplemented!", log: OSLog.log, type: .error)
   }

   public func peripheralDidUpdateRSSI(_ peripheral: CBPeripheral, error: Error?) {
      os_log("CBPeripheralDelegate.peripheralDidUpdateRSSI unimplemented!", log: OSLog.log, type: .error)
   }

   public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
      os_log("CBPeripheralDelegate.didReadRSSI unimplemented!", log: OSLog.log, type: .error)
   }

   public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
      if let error = error {
         os_log("CBPeripheralDelegate.didDiscoverServices(uuid=%s) error=%{public}s)", log: OSLog.log, type: .error,
                peripheral.identifier.uuidString,
                String(describing: error))
         delegate?.didFailToConnectToPeripheral(uuid: peripheral.identifier, error: error)
      }
      else {
         // Iterate over the newly discovered services (just in case there's more than one) and discover characteristics for each
         if let peripheralServices = peripheral.services {
            os_log("CBPeripheralDelegate.didDiscoverServices(uuid=%s): iterating over %d services:", log: OSLog.log, type: .debug,
                   peripheral.identifier.uuidString,
                   peripheralServices.count)

            for service in peripheralServices {
               os_log("CBPeripheralDelegate.didDiscoverServices(uuid=%s): discovering characteristics for service [%s]", log: OSLog.log, type: .debug,
                      peripheral.identifier.uuidString,
                      service.uuid.uuidString)

               if let characteristicsUUIDs = servicesAndCharacteristics.characteristicUUIDs(belongingToService: service) {
                  peripheral.discoverCharacteristics(Array(characteristicsUUIDs), for: service)
               }
               else {
                  peripheral.discoverCharacteristics(nil, for: service)
               }
            }
         }
         else {
            os_log("CBPeripheralDelegate.didDiscoverServices(uuid=%s): no services found!", log: OSLog.log, type: .error, peripheral.identifier.uuidString)
            delegate?.didFailToConnectToPeripheral(uuid: peripheral.identifier, error: BLEError.noServicesFound)
         }
      }
   }

   public func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
      os_log("CBPeripheralDelegate.didDiscoverIncludedServicesFor unimplemented!", log: OSLog.log, type: .error)
   }

   public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
      let uuid = peripheral.identifier

      if var peripheralInfo = peripheralInfoByUUID[uuid] {
         if let error = error {
            os_log("CBPeripheralDelegate.didDiscoverCharacteristicsFor(uuid=%s|service=%s) error=%{public}s)", log: OSLog.log, type: .error,
                   uuid.uuidString,
                   service.uuid.uuidString,
                   String(describing: error))

            delegate?.didFailToConnectToPeripheral(uuid: uuid, error: error)
         }
         else {
            // verify that we found all expected characteristics
            if let serviceCharacteristics = service.characteristics {
               var expectedCharacteristicUUIDs: Set<String> = Set((servicesAndCharacteristics.characteristicUUIDs(belongingToService: service) ?? []).map {
                  $0.uuidString
               })
               for characteristic in serviceCharacteristics {
                  os_log("CBPeripheralDelegate.didDiscoverCharacteristicsFor(uuid=%s|service=%s): found characteristic [%s]", log: OSLog.log, type: .debug,
                         uuid.uuidString,
                         service.uuid.uuidString,
                         characteristic.uuid.uuidString)
                  expectedCharacteristicUUIDs.remove(characteristic.uuid.uuidString)
               }

               // create a BLEPeripheral
               let blePeripheral = StandardBLEPeripheral(peripheral: peripheral, advertisementData: peripheralInfo.advertisementData)

               // update state
               peripheralInfo.state = .connectedAndDiscovered
               peripheralInfo.blePeripheral = blePeripheral
               peripheralInfoByUUID[uuid] = peripheralInfo

               delegate?.didConnectToPeripheral(peripheral: blePeripheral)
            }
            else {
               os_log("CBPeripheralDelegate.didDiscoverCharacteristicsFor(uuid=%s|service=%s) no characteristics found!", log: OSLog.log, type: .error,
                      uuid.uuidString,
                      service.uuid.uuidString)
               delegate?.didFailToConnectToPeripheral(uuid: uuid, error: BLEError.noCharacteristicsFound)
            }
         }
      }
      else {
         os_log("CBPeripheralDelegate.didDiscoverCharacteristicsFor: ignoring for undiscovered peripheral [%s]", log: OSLog.log, type: .error, uuid.uuidString)
      }
   }

   public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
      os_log("CBPeripheralDelegate.didUpdateValueForCharacteristic unimplemented, should be handled by peripheral!", log: OSLog.log, type: .error)
   }

   public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
      os_log("CBPeripheralDelegate.didWriteValueForCharacteristic unimplemented, should be handled by peripheral!", log: OSLog.log, type: .error)
   }

   public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
      os_log("CBPeripheralDelegate.didUpdateNotificationStateForCharacteristic unimplemented, should be handled by peripheral!", log: OSLog.log, type: .error)
   }

   public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
      os_log("CBPeripheralDelegate.didDiscoverDescriptorsForCharacteristic unimplemented, should be handled by peripheral!", log: OSLog.log, type: .error)
   }

   public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
      os_log("CBPeripheralDelegate.didUpdateValueForDescriptor unimplemented, should be handled by peripheral!", log: OSLog.log, type: .error)
   }

   public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
      os_log("CBPeripheralDelegate.didWriteValueForDescriptor unimplemented, should be handled by peripheral!", log: OSLog.log, type: .error)
   }

   public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
      os_log("CBPeripheralDelegate.peripheralIsReady unimplemented, should be handled by peripheral!", log: OSLog.log, type: .error)
   }

   @available(iOS 11.0, *)
   public func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
      os_log("CBPeripheralDelegate.didOpenChannel unimplemented, should be handled by peripheral!", log: OSLog.log, type: .error)
   }
}
