//
// Created by Chris Bartley on 4/24/20.
//

import Foundation

public protocol UARTDevice: UARTDeviceIdentifier {
   var advertisementSignature: AdvertisementSignature? { get }

   var delegate: UARTDeviceDelegate? { get set }

   func startStateChangeNotifications() -> Bool
   func stopStateChangeNotifications() -> Bool

   func writeWithResponse(bytes: [UInt8])
   func writeWithResponse(data: Data)
   func writeWithoutResponse(bytes: [UInt8])
   func writeWithoutResponse(data: Data)
}