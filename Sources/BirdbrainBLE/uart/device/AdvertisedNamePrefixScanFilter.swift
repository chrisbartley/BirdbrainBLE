//
// Created by Chris Bartley on 5/7/20.
//

import Foundation
import CoreBluetooth

public class AdvertisedNamePrefixScanFilter: UARTDeviceScanFilter {
   public func isOfType(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber) -> Bool {
      if let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] {
         let advertisedNameStr = String(describing: advertisedName)
         return (isCaseSensitive ? advertisedNameStr : advertisedNameStr.lowercased()).starts(with: prefix)
      }

      return false
   }

   private let prefix: String
   private let isCaseSensitive: Bool

   public init(prefix: String, isCaseSensitive: Bool = true) {
      self.isCaseSensitive = isCaseSensitive
      self.prefix = isCaseSensitive ? prefix : prefix.lowercased()
   }
}