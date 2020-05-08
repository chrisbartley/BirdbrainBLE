import Foundation
import os

extension OSLog {
   static private let DEFAULT_BUNDLE_IDENTIFIER = "com.birdbraintechnologies.ble"

   convenience init(category: String) {
      self.init(subsystem: Bundle.main.bundleIdentifier ?? OSLog.DEFAULT_BUNDLE_IDENTIFIER, category: category)
   }
}