//
// Created by Chris Bartley on 9/1/20.
//

import Foundation
import os
import CoreBluetooth

fileprivate extension OSLog {
   static let log = OSLog(category: "StandardBroadcastBLECentralManager")
}

public class StandardBroadcastBLECentralManager: NSObject {

   static public let defaultAssumeDisappearanceTimeInterval: TimeInterval = 3.0

   //MARK: - Public Properties

   public weak var delegate: BroadcastBLECentralManagerDelegate?

   //MARK: - Private Properties

   private var centralManager: CBCentralManager!
   private let servicesAndCharacteristics: SupportedServicesAndCharacteristics
   private var peripheralInfoByUUID = [UUID : (
         peripheral: CBPeripheral,
         advertisementData: [String : Any],
         lastSeen: Date // motivated by https://fivepackcreative.com/3-things-know-ios-bluetooth-coding/
   )]()

   //MARK: - Initializers

   public convenience init(servicesAndCharacteristics: SupportedServicesAndCharacteristics,
                           delegate: BroadcastBLECentralManagerDelegate) {
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
   /// `StandardBroadcastBLECentralManager.defaultAssumeDisappearanceTimeInterval` seconds. Duplicates are allowed.
   ///
   /// - Parameter timeoutSecs: number of seconds to scan until timing out
   /// - Returns: true if scanning was successfully initiated; false otherwise.
   @discardableResult
   public func startScanning(timeoutSecs: TimeInterval) -> Bool {
      return startScanning(timeoutSecs: timeoutSecs,
                           assumeDisappearanceAfter: StandardBroadcastBLECentralManager.defaultAssumeDisappearanceTimeInterval,
                           allowDuplicates: true)
   }

   /// Starts scanning, with a timeout of `timeoutSecs`, and assumes disappearance after the given `assumeDisappearanceAfter`
   /// TimeInterval (or `StandardBroadcastBLECentralManager.defaultAssumeDisappearanceTimeInterval` if not provided).
   ///
   /// - Parameters:
   ///   - timeoutSecs: number of seconds to scan until timing out
   ///   - assumeDisappearanceAfter: TimeInterval before considering a peripheral as having disappeared
   ///   - allowDuplicates: whether to allow duplicate scan discoveries, defaults to true
   /// - Returns:
   @discardableResult
   public func startScanning(timeoutSecs: TimeInterval,
                             assumeDisappearanceAfter: TimeInterval = StandardBroadcastBLECentralManager.defaultAssumeDisappearanceTimeInterval,
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
               // if this peripheral hasn't been seen recently, then flag it as disappeared
               if abs(peripheralInfo.lastSeen.timeIntervalSinceNow) >= abs(assumeDisappearanceAfter) {
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

extension StandardBroadcastBLECentralManager: CBCentralManagerDelegate {
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
         peripheralInfo.advertisementData = peripheralInfo.advertisementData.merging(advertisementData) { (_, new) in
            new
         }
         peripheralInfoByUUID[uuid] = peripheralInfo

         // os_log("CBCentralManagerDelegate.didDiscover: Re-discovered peripheral [%s] total=%d state=[%{public}s|%{public}s]", log: OSLog.log, type: .debug,
         //        uuid.uuidString,
         //        peripheralInfoByUUID.count,
         //        String(describing: peripheralInfo.state),
         //        String(describing: peripheralInfo.peripheral.state))

         // when notifying the delegate, send the *merged* advertisementData, rather than the one we just received, so
         // that we'll be sure to include everything we've ever known about the peripheral (for our purposes, this
         // ensures that we always include the (last-known) advertising name).
         delegate?.didDiscoverPeripheral(uuid: uuid, advertisementData: peripheralInfo.advertisementData, rssi: rssi, isRediscovery: true)
      }
      else {
         // add it to the peripheralInfo collection
         peripheralInfoByUUID[uuid] = (peripheral: peripheral,
                                       advertisementData: advertisementData,
                                       lastSeen: Date())

         // notifiy the delegate of the new peripheral
         os_log("CBCentralManagerDelegate.didDiscover: Discovered peripheral [%s] total=%d", log: OSLog.log, type: .debug,
                uuid.uuidString,
                peripheralInfoByUUID.count)
         delegate?.didDiscoverPeripheral(uuid: uuid, advertisementData: advertisementData, rssi: rssi, isRediscovery: false)
      }
   }

   public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
      os_log("CBCentralManagerDelegate.didConnect: ignoring didConnect for peripheral [%s]", log: OSLog.log, type: .info, peripheral.identifier.uuidString)
   }

   public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
      os_log("CBCentralManagerDelegate.didDisconnectPeripheral: ignoring didDisconnectPeripheral for peripheral [%s]", log: OSLog.log, type: .info, peripheral.identifier.uuidString)
   }

   public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
      os_log("CBCentralManagerDelegate.didFailToConnect: ignoring didFailToConnect for peripheral [%s]", log: OSLog.log, type: .info, peripheral.identifier.uuidString)
   }
}