//
// Created by Chris Bartley on 4/28/20.
//

import Foundation

public protocol ManageableUARTDevice: UARTDeviceIdentifier {
   init(blePeripheral: BLEPeripheral)
}