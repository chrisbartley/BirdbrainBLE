//
// Created by Chris Bartley on 4/14/20.
//

import Foundation
import CoreBluetooth

public protocol BLECentralManagerDelegate {
   func didUpdateState(to state: CBManagerState)
   func didPowerOn()
   func didPowerOff()
   func didScanTimeout()
   func didDiscoverPeripheral(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber)
   func didRediscoverPeripheral(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber)
   func didConnectToPeripheral(peripheral: BLEPeripheral)
   func didDisconnectFromPeripheral(uuid: UUID, error: Error?)
   func didFailToConnectToPeripheral(uuid: UUID, error: Error?)
}
