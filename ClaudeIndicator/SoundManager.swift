import Foundation
import AppKit
import AVFoundation
import AudioToolbox

class SoundManager {
    static func playAlert() {
        // Use system alert sound
        AudioServicesPlayAlertSound(SystemSoundID(1000))
    }
}
