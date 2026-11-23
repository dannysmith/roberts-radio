import SwiftUI

/// Buttons that open and close the presets and browse panels.
struct SidePanelButtons: View {
    let vm: RadioViewModel
    @Binding var selection: SidePanel

    var body: some View {
        HStack(spacing: 8) {
            toggle("Presets", icon: "list.bullet", panel: .presets)
            toggle("Browse", icon: "folder", panel: .browse)
            Spacer()
        }
    }

    private func toggle(_ label: String, icon: String, panel: SidePanel) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = selection == panel ? .none : panel
            }
            if selection == .browse, vm.browseItems.isEmpty {
                vm.startBrowse()
            }
        } label: {
            Label(label, systemImage: icon)
                .font(.system(size: 11))
        }
        .buttonStyle(.bordered)
        .tint(selection == panel ? .accentColor : .secondary)
        .controlSize(.small)
    }
}

struct SidePanelView: View {
    let vm: RadioViewModel
    @Binding var panel: SidePanel
    @Binding var filterText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(panel == .presets ? "Presets" : "Browse")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { panel = .none }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.bottom, 8)

            if panel == .presets {
                PresetsPanel(vm: vm)
            } else {
                BrowsePanel(vm: vm, filterText: $filterText)
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 8)
    }
}

private struct PresetsPanel: View {
    let vm: RadioViewModel

    var body: some View {
        if vm.presets.isEmpty {
            Text("No presets for this mode")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(vm.presets) { preset in
                        PresetRow(number: preset.id + 1, name: preset.name) {
                            Task { await vm.selectPreset(preset.id) }
                        }
                    }
                }
            }
        }
    }
}

private struct PresetRow: View {
    let number: Int
    let name: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("\(number)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, alignment: .trailing)
                Text(name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(hovered ? Color.accentColor.opacity(0.15) : .clear, in: .rect(cornerRadius: 4))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct BrowsePanel: View {
    let vm: RadioViewModel
    @Binding var filterText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BrowseFilterField(text: $filterText)
            BrowseNavigationBar(vm: vm, filterText: $filterText)
            BrowseItems(vm: vm, filterText: $filterText)
        }
    }
}

private struct BrowseFilterField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            TextField("Filter...", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

private struct BrowseNavigationBar: View {
    let vm: RadioViewModel
    @Binding var filterText: String

    var body: some View {
        HStack(spacing: 4) {
            if vm.browseDepth > 0 {
                Button {
                    filterText = ""
                    vm.browseBack()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left").font(.system(size: 10))
                        Text("Back").font(.system(size: 11))
                    }
                }
                .buttonStyle(.borderless)
            }
            Text(vm.browseTitle.isEmpty ? vm.modeName : vm.browseTitle)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

private struct BrowseItems: View {
    let vm: RadioViewModel
    @Binding var filterText: String

    var body: some View {
        if vm.isBrowseLoading {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else if vm.browseItems.isEmpty {
            emptyMessage("No items")
        } else if filteredItems.isEmpty {
            emptyMessage("No matches")
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredItems) { item in
                        BrowseRow(name: item.name, isFolder: item.isFolder) {
                            filterText = ""
                            if item.isFolder {
                                vm.browseInto(item.id)
                            } else {
                                vm.browseSelect(item.id)
                            }
                        }
                    }
                }
            }
        }
    }

    private var filteredItems: [BrowseItem] {
        guard !filterText.isEmpty else { return vm.browseItems }
        return vm.browseItems.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
    }

    private func emptyMessage(_ message: LocalizedStringKey) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }
}

private struct BrowseRow: View {
    let name: String
    let isFolder: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isFolder ? "folder.fill" : "music.note")
                    .font(.system(size: 10))
                    .foregroundStyle(isFolder ? Color.accentColor : .secondary)
                    .frame(width: 14)
                Text(name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer()
                if isFolder {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(hovered ? Color.accentColor.opacity(0.15) : .clear, in: .rect(cornerRadius: 4))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
