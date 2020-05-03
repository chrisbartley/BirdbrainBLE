//
// Created by Chris Bartley on 4/18/20.
//

import Foundation

enum BLEError: Error {
   case noServicesFound
   case noCharacteristicsFound
}

// Enable more human-readable printing/logging
extension BLEError: CustomStringConvertible {
   public var description: String {
      switch self {
         case .noServicesFound: return "No Services Found"
         case .noCharacteristicsFound: return "No Characteristics Found"
      }
   }
}