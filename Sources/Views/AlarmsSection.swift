import SwiftUI

/// Collapsible list of the radio's alarms, fetched the first time it's expanded.
struct AlarmsSection: View {
    let vm: RadioViewModel
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                isExpanded.toggle()
                if isExpanded, vm.alarms.isEmpty {
                    Task { await vm.fetchAlarms() }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "alarm").font(.system(size: 10))
                    Text("Alarms").font(.caption)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.borderless)

            if isExpanded {
                if vm.alarms.isEmpty {
                    Text("No alarms configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 2) {
                        ForEach(vm.alarms) { alarm in
                            AlarmRow(alarm: alarm)
                        }
                    }
                }
            }
        }
    }
}

private struct AlarmRow: View {
    let alarm: RadioAlarm

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(alarm.isEnabled ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 6, height: 6)
            Text(alarm.time).font(.system(size: 11, weight: .medium, design: .monospaced))
            if let days = alarm.days {
                Text(days).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            if let volume = alarm.volume {
                Image(systemName: "speaker.wave.1.fill").font(.system(size: 8)).foregroundStyle(.secondary)
                Text(volume).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .opacity(alarm.isEnabled ? 1.0 : 0.5)
    }
}
