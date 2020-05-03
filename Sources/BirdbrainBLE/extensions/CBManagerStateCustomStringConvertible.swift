//
// Created by Chris Bartley on 4/14/20.
//

import Foundation
import CoreBluetooth

// Enable more human-readable printing/logging of manager state
extension CBManagerState: CustomStringConvertible {
   public var description: String {
      switch self {
         case .unknown: return "Unknown"
         case .resetting: return "Resetting"
         case .unsupported: return "Unsupported"
         case .unauthorized: return "Unauthorized"
         case .poweredOff: return "Powered Off"
         case .poweredOn: return "Powered On"
         @unknown default: return "Unexpected State"
      }
   }
}