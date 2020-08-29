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

   /// Returns the maximum amount of data, in bytes, you can send in a single write-with-response.
   func maximumWriteWithResponseDataLength() -> Int

   /// Returns the maximum amount of data, in bytes, you can send in a single write-without-response.
   func maximumWriteWithoutResponseDataLength() -> Int
}