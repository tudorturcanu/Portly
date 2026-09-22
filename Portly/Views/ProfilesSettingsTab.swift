//
//  ProfilesSettingsTab.swift
//  Portly
//

import SwiftUI

/// Settings tab for creating and managing Project Port Profiles (e.g. "Frontend Stack", "Data Pipeline").
struct ProfilesSettingsTab: View {
    var monitor: PortMonitor

    @State private var showingAddSheet = false
    @State private var newProfileName = ""
    @State private var newProfilePortsText = ""
    @State private var selectedActivePorts: Set<Int> = []

    private var profileManager: DevProfileManager {
        DevProfileManager.shared
    }

    var body: some View {
        Form {
            Section {
                if profileManager.profiles.isEmpty {
                    ContentUnavailableView {
                        Label("No Project Profiles", systemImage: "square.stack.3d.up")
                    } description: {
                        Text("Create profiles to organize your dev servers into project stacks (e.g. Web App, Microservices).")
                    } actions: {
                        Button("Create Profile…") {
                            prepareNewProfile()
                        }
                    }
                    .padding(.vertical, 12)
                } else {
                    ForEach(profileManager.profiles) { profile in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(profile.name)
                                    .font(.headline)

                                Spacer()

                                if profileManager.activeProfileId == profile.id {
                                    Text("Active Filter")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.tint)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.12), in: .capsule)
                                }

                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    profileManager.deleteProfile(id: profile.id)
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                            }

                            HStack(spacing: 6) {
                                ForEach(profile.ports, id: \.self) { port in
                                    let isRunning = monitor.ports.contains(where: { $0.port == port })
                                    HStack(spacing: 3) {
                                        Circle()
                                            .fill(isRunning ? Color.green : Color.secondary.opacity(0.5))
                                            .frame(width: 5, height: 5)
                                        Text(":\(port)")
                                            .font(.system(.caption2, design: .monospaced))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary, in: .capsule)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                HStack {
                    Text("Dev Profiles (Project Stacks)")
                    Spacer()
                    if !profileManager.profiles.isEmpty {
                        Button("Add Profile…", systemImage: "plus") {
                            prepareNewProfile()
                        }
                        .buttonStyle(.borderless)
                    }
                }
            } footer: {
                Text("Selecting a profile filters Portly's menu view to show only services for that project, highlighting any missing or stopped dependencies.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAddSheet) {
            addProfileSheet
        }
    }

    private var addProfileSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create Dev Profile")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Profile Name:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. E-Commerce Stack, Full Stack Web", text: $newProfileName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Ports (comma-separated):")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("3000, 8000, 5432", text: $newProfilePortsText)
                    .textFieldStyle(.roundedBorder)
            }

            if !monitor.ports.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Pick Active Ports:")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(monitor.ports) { port in
                                let isSelected = selectedActivePorts.contains(port.port)
                                Button {
                                    if isSelected {
                                        selectedActivePorts.remove(port.port)
                                    } else {
                                        selectedActivePorts.insert(port.port)
                                    }
                                    updatePortsText()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        Text(":\(port.port) \(port.displayName)")
                                            .font(.system(.caption, design: .monospaced))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.15)) : AnyShapeStyle(.quaternary.opacity(0.5)), in: .capsule)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    showingAddSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save Profile") {
                    saveProfile()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty || newProfilePortsText.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 400)
    }

    private func prepareNewProfile() {
        newProfileName = ""
        selectedActivePorts = Set(monitor.ports.prefix(3).map(\.port))
        updatePortsText()
        showingAddSheet = true
    }

    private func updatePortsText() {
        newProfilePortsText = selectedActivePorts.sorted().map(String.init).joined(separator: ", ")
    }

    private func saveProfile() {
        let trimmedName = newProfileName.trimmingCharacters(in: .whitespaces)
        let parsedPorts = newProfilePortsText
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }

        guard !trimmedName.isEmpty, !parsedPorts.isEmpty else { return }

        profileManager.addProfile(name: trimmedName, ports: parsedPorts)
        showingAddSheet = false
    }
}
