import SwiftUI

/// IP, PIN and discovery controls.
struct SettingsFields: View {
    let vm: RadioViewModel
    @State private var ipField = ""
    @State private var pinField = ""

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                TextField("IP address", text: $ipField)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .onSubmit { vm.connect(to: ipField) }
                Button("Set") { vm.connect(to: ipField) }
                    .controlSize(.small)
            }
            HStack(spacing: 4) {
                Text("PIN").font(.system(size: 10)).foregroundStyle(.secondary)
                TextField("PIN", text: $pinField)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 60)
                    .onSubmit { vm.updatePin(pinField) }
                Spacer()
                Button {
                    Task { await vm.discover() }
                } label: {
                    HStack(spacing: 4) {
                        if vm.isDiscovering {
                            ProgressView().controlSize(.small).scaleEffect(0.7)
                        }
                        Text(vm.isDiscovering ? "Searching..." : "Discover")
                    }
                }
                .controlSize(.small)
                .disabled(vm.isDiscovering)
            }
        }
        .onAppear {
            ipField = vm.radioIP
            pinField = vm.radioPin
        }
        .onChange(of: vm.radioIP) {
            ipField = vm.radioIP
        }
    }
}

struct BottomBar: View {
    let vm: RadioViewModel
    @Binding var showSettings: Bool

    var body: some View {
        HStack {
            if showSettings, vm.isConnected {
                VStack(alignment: .leading, spacing: 4) {
                    SettingsFields(vm: vm)
                    Button("Done") { showSettings = false }
                        .controlSize(.small)
                }
            } else {
                Button {
                    withAnimation { showSettings.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gear").font(.system(size: 11))
                        if vm.isConnected {
                            Text(vm.radioIP)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.borderless)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
