//
// Created by Chris Bartley on 4/26/20.
//

import Foundation

public protocol UARTDeviceScanFilter {
   func isOfType(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber) -> Bool
}