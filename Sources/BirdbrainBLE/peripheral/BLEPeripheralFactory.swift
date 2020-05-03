//
// Created by Chris Bartley on 4/15/20.
//

import Foundation
import CoreBluetooth

public protocol BLEPeripheralFactory: BLEPeripheralUUIDs {
   func create(peripheral: CBPeripheral, advertisementData: [String : Any]) -> BLEPeripheral
}
