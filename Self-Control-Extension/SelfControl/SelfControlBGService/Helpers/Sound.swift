//
//  Sound.swift
//  SelfControl
//
//  Created by Satendra Singh on 31/05/26.
//

import AppKit
import os.log

public extension NSSound {

    enum Sound: String {
        case basso = "Basso"
        case blow = "Blow"
        case bottle = "Bottle"
        case frog = "Frog"
        case funk = "Funk"
        case glass = "Glass"
        case hero = "Hero"
        case morse = "Morse"
        case ping = "Ping"
        case pop = "Pop"
        case purr = "Purr"
        case sosumi = "Sosumi"
        case submarine = "Submarine"
        case tink = "Tink"
    }
    
    var soundName: String? {
        return self.name
    }
    
    static func play(_ sound: Sound) {
        NSSound(named: NSSound.Name(sound.rawValue))?.play()
    }
    
    static func playDefaultSound() {
        play(.basso)
    }
}

struct Sound {
    static func checkAndPlay() {
        os_log("[SC] 🔍] BG checkAndPlay: %{public}d",HelperAppPreferences.playSoundOnCompletion)
        if HelperAppPreferences.playSoundOnCompletion {
            NSSound.playDefaultSound()
        }
    }
}
