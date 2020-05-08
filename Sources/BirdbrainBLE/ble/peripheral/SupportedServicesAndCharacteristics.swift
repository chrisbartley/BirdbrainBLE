//
// Created by Chris Bartley on 4/15/20.
//

import Foundation
import CoreBluetooth

public protocol SupportedServicesAndCharacteristics {
   var serviceUUIDs: [CBUUID] { get }

   func characteristicUUIDs(belongingToService service: CBService) -> [CBUUID]?
}
