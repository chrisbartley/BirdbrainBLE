//
// Created by Chris Bartley on 4/14/20.
//

import Foundation
import CoreBluetooth

// Enable more human-readable printing/logging of peripheral state
extension CBPeripheralState: CustomStringConvertible {
   public var description: String {
      switch self {
         case .disconnected: return "Disconnected"
         case .connecting: return "Connecting"
         case .connected: return "Connected"
         case .disconnecting: return "Disconnecting"
         @unknown default: return "Unexpected State"
      }
   }
}
