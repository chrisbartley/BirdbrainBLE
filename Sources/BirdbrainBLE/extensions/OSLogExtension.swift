import Foundation
import os

extension OSLog {
   static private let DEFAULT_BUNDLE_IDENTIFIER = "com.birdbraintechnologies.ble"

   static let standardBLECentralManager = OSLog(category: "StandardBLECentralManager")
   static let standardBLEPeripheral = OSLog(category: "StandardBLEPeripheral")

   private convenience init(category: String) {
      self.init(subsystem: Bundle.main.bundleIdentifier ?? OSLog.DEFAULT_BUNDLE_IDENTIFIER, category: category)
   }
}