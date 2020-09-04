//
// Created by Chris Bartley on 9/1/20.
//

import Foundation

public protocol BroadcastBLECentralManager {
   var delegate: BroadcastBLECentralManagerDelegate? { get set }
   func startScanning(timeoutSecs: TimeInterval) -> Bool
   func stopScanning() -> Bool
}
