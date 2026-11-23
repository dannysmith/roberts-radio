// Menubar app for controlling a Roberts Revival iStream 3L via FSAPI.
// Build and run with bin/radiobar-gui.

import MenuBarExtraAccess
import SwiftUI

// MARK: - App

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        if !CommandLine.arguments.contains("--dock") {
            NSApp.setActivationPolicy(.accessory)
        }
        Log("APP: Launched")
    }
}

@main
struct RadioBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var vm: RadioViewModel
    @State private var macSpeaker: MacSpeaker

    init() {
        let radio = RadioViewModel()
        vm = radio
        macSpeaker = MacSpeaker(radio: radio)
    }

    var body: some Scene {
        MenuBarExtra {
            RadioMenuView(vm: vm, macSpeaker: macSpeaker)
                .introspectMenuBarExtraWindow { window in
                    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                    window.isMovable = false
                    // Pin to the screen that owns the menubar icon
                    if let screen = window.screen ?? NSApp.keyWindow?.screen {
                        window.setFrame(window.frame, display: true)
                        window.constrainFrameRect(window.frame, to: screen)
                    }
                }
        } label: {
            Image(systemName: vm.isConnected && vm.power ? "radio.fill" : "radio")
        }
        .menuBarExtraAccess(isPresented: $vm.isPopoverPresented)
        .menuBarExtraStyle(.window)
    }
}
