//
// Created by Chris Bartley on 4/15/20.
//

import Foundation
import CoreBluetooth

public protocol BLEPeripheralUUIDs {
   var serviceUUIDs: [CBUUID] { get }

   func characteristicUUIDs(belongingToService service: CBService) -> [CBUUID]?
}
