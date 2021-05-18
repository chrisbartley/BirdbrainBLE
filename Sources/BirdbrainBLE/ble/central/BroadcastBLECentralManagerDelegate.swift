//
// Created by Chris Bartley on 9/1/20.
//

import Foundation
import CoreBluetooth

public protocol BroadcastBLECentralManagerDelegate: AnyObject {
   func didUpdateState(to state: CBManagerState)
   func didPowerOn()
   func didPowerOff()
   func didScanTimeout()
   func didDiscoverPeripheral(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber, isRediscovery: Bool)
   func didPeripheralDisappear(uuid: UUID)
}

public extension BroadcastBLECentralManagerDelegate {
   func didUpdateState(to state: CBManagerState) {}

   func didPowerOn() {}

   func didPowerOff() {}

   func didScanTimeout() {}

   func didDiscoverPeripheral(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber, isRediscovery: Bool) {}

   func didPeripheralDisappear(uuid: UUID) {}
}