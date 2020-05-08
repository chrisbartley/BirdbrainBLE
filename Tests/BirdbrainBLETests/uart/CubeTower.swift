//
// Created by Chris Bartley on 4/24/20.
//

import Foundation
import CoreGraphics

@testable import BirdbrainBLE

public class CubeTower: BaseUARTDevice, ManageableUARTDevice {
   private static let ledCommand: [UInt8] = [0xE0]
   private static let ledOffCommand: [UInt8] = ledCommand + [0x00, 0x00, 0x00, /* ones */
                                                             0x00, 0x00, 0x00, /* tens */
                                                             0x00, 0x00, 0x00  /* hundreds */]

   private func rgbIntColorToByteArray(rgb: Int) -> [UInt8] {
      return [UInt8((rgb >> 16) & 0xFF),
              UInt8((rgb >> 8) & 0xFF),
              UInt8(rgb & 0xFF)]
   }

   func setLEDs(left: Int, middle: Int, right: Int) {
      self.writeWithoutResponse(bytes: [0xE0] +
                                       rgbIntColorToByteArray(rgb: right) +
                                       rgbIntColorToByteArray(rgb: middle) +
                                       rgbIntColorToByteArray(rgb: left))
   }

   func turnLEDsOff() {
      self.writeWithoutResponse(bytes: CubeTower.ledOffCommand)
   }
}