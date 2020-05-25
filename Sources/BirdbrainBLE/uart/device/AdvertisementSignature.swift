//
// Created by Chris Bartley on 5/24/20.
//

import Foundation
import CoreGraphics
import CoreBluetooth

#if canImport(UIKit)
   import UIKit
#endif

public struct AdvertisementSignature {
   static private let colors = [
      CGColor.create(rgb: 0xFF0000), // red
      CGColor.create(rgb: 0x00FF00), // green
      CGColor.create(rgb: 0x0000FF), // blue
      CGColor.create(rgb: 0xFFFF00), // yellow
      CGColor.create(rgb: 0xFF00FF), // magenta
      CGColor.create(rgb: 0x00FFFF), // teal
      CGColor.create(rgb: 0xFFFFFF), // white
   ]

   public let advertisedName: String
   public let deviceName: String
   public let memorableName: String?
   public let colors: (color0: CGColor, color1: CGColor, color2: CGColor)

   public init?(advertisementData: [String : Any]) {
      self.init(advertisedName: advertisementData[CBAdvertisementDataLocalNameKey] as? String)
   }

   public init?(advertisedName: String?) {
      // We generate the advertisement signature from the last five characters of the BLE advertised name (those
      // characters are typically from the device's MAC address which is not available via Core Bluetooth.
      // See https://forums.developer.apple.com/thread/8442 for more info)
      if let advertisedName = advertisedName {
         if advertisedName.count >= 5 {
            let deviceName = String(advertisedName.suffix(5))

            // Treat the 5-character deviceName as hex chars (thus 20 bits) and try to convert to an Int. Then we'll
            // grab bits from the MAC address, like this:
            //
            //    6 bits, 6 bits, 8 bits => last, middle, first (llllllmmmmmmffffffff)
            //
            if let macNumber = Int(deviceName, radix: 16) {
               let first8 = macNumber & 0b11111111
               let middle6 = (macNumber >> 8) & 0b111111
               let last6 = (macNumber >> 14) & 0b111111

               let first8right4 = first8 & 0b1111
               let first8left4 = first8 >> 4

               self.advertisedName = advertisedName
               self.deviceName = deviceName
               self.memorableName = MemorableNameGenerator.instance.generateNameFrom(advertisedName: advertisedName)
               self.colors = (
                     color0: AdvertisementSignature.colors[Int(first8right4 + first8left4) % AdvertisementSignature.colors.count],
                     color1: AdvertisementSignature.colors[Int(middle6) % AdvertisementSignature.colors.count],
                     color2: AdvertisementSignature.colors[Int(last6) % AdvertisementSignature.colors.count]
               )
               return
            }
         }
      }

      return nil
   }
}

// Based on https://stackoverflow.com/a/24263296/703200
extension CGColor {
   static func create(red: Int, green: Int, blue: Int, alpha: CGFloat = 1.0) -> CGColor {
      assert(red >= 0 && red <= 255, "Invalid red component")
      assert(green >= 0 && green <= 255, "Invalid green component")
      assert(blue >= 0 && blue <= 255, "Invalid blue component")

      #if os(iOS)
         return UIColor(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: alpha).cgColor
      #else
         return CGColor(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: alpha)
      #endif
   }

   static func create(rgb: Int, alpha: CGFloat = 1.0) -> CGColor {
      return CGColor.create(red: (rgb >> 16) & 0xFF,
                            green: (rgb >> 8) & 0xFF,
                            blue: rgb & 0xFF,
                            alpha: alpha)
   }
}
