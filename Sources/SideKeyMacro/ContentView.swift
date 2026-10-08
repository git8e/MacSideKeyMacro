import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    permissionCard
                    triggerCard
                    statusCard
                    languageCard
                }
                .frame(width: 340)

                macroCard
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            footer
        }
        .padding(18)
        .frame(minWidth: 900, minHeight: 640)
        .onAppear {
            model.refreshPermissions()
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            model.refreshPermissions()
        }
        .onDisappear {
            model.shutdown()
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "computermouse.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            Text(L10n.appTitle)
                .font(.title2)
                .fontWeight(.bold)
            Text("SideKeyMacro")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(model.isRunning ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(model.statusText)
                    .font(.callout)
                    .monospacedDigit()
            }
        }
    }

    private var footer: some View {
        Text(L10n.footerUsage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - 权限

    private var permissionCard: some View {
        GroupBox(L10n.cardPermission) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(model.accessibilityGranted ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(model.accessibilityGranted ? L10n.a11yGranted : L10n.a11yDenied)
                    Spacer()
                }
                .font(.callout)

                HStack(spacing: 8) {
                    Button(L10n.goToSettings) { model.requestAccessibility() }
                    Button(L10n.refreshStatus) { model.refreshPermissions() }
                }

                if let message = model.monitorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 触发

    private var triggerCard: some View {
        GroupBox(L10n.cardTrigger) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(L10n.enableMonitor, isOn: $model.monitorEnabled)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.triggerSideKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $model.sideButton) {
                        ForEach(SideButton.allCases) { button in
                            Text(button.title).tag(button)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                Toggle(L10n.interceptToggle, isOn: $model.interceptSideKey)

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.triggerModeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $model.triggerMode) {
                        ForEach(MacroRunner.TriggerMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    Text(model.triggerMode.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 状态 / 手动控制

    private var statusCard: some View {
        GroupBox(L10n.cardManual) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(model.isRunning ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(model.statusText)
                    Spacer()
                }
                .font(.callout)

                HStack(spacing: 8) {
                    Button {
                        if model.isRunning {
                            model.stop()
                        } else {
                            model.runTest()
                        }
                    } label: {
                        Label(model.isRunning ? L10n.stopButton : L10n.runOnceButton,
                              systemImage: model.isRunning ? "stop.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: [.command])
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 语言

    private var languageCard: some View {
        GroupBox(L10n.cardSettings) {
            HStack(spacing: 8) {
                Text(L10n.languageLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $model.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(L10n.languageOption(lang)).tag(lang)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                Spacer()
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 宏脚本库

    private var macroCard: some View {
        GroupBox(L10n.cardMacro) {
            VStack(alignment: .leading, spacing: 10) {
                scriptToolbar
                nameRow

                ZStack(alignment: .topLeading) {
                    ScriptTextView(text: scriptTextBinding)
                        .id(model.selectedScriptID)
                        .frame(minHeight: 280)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .textBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.35))
                                )
                        )

                    if model.selectedScript?.text.isEmpty ?? true {
                        Text(L10n.scriptPlaceholder)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(14)
                            .allowsHitTesting(false)
                    }
                }

                parseInfoRow

                HStack(spacing: 8) {
                    Text(L10n.defaultHoldLabel)
                        .font(.caption)
                    Slider(value: $model.defaultHoldMs, in: 5...200, step: 5)
                    Text("\(Int(model.defaultHoldMs)) ms")
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                }

                Text(L10n.supportedTags)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .confirmationDialog(
            L10n.deleteConfirmTitle(name: model.scripts.first(where: { $0.id == pendingDeleteID })?.displayName ?? ""),
            isPresented: deleteConfirmBinding
        ) {
            Button(L10n.deleteButton, role: .destructive) {
                if let id = pendingDeleteID {
                    model.deleteScript(id: id)
                }
                pendingDeleteID = nil
            }
            Button(L10n.cancelButton, role: .cancel) {
                pendingDeleteID = nil
            }
        } message: {
            Text(L10n.deleteConfirmWarning)
        }
    }

    @State private var pendingDeleteID: UUID?

    private var deleteConfirmBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteID != nil },
            set: { if !$0 { pendingDeleteID = nil } }
        )
    }

    private var scriptToolbar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $model.selectedScriptID) {
                ForEach(model.scripts) { script in
                    Text(script.displayName).tag(script.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 220)

            Button {
                model.addScript()
            } label: {
                Label(L10n.addButton, systemImage: "plus")
            }

            Button {
                model.duplicateSelectedScript()
            } label: {
                Label(L10n.duplicateButton, systemImage: "doc.on.doc")
            }

            Button(role: .destructive) {
                pendingDeleteID = model.selectedScriptID
            } label: {
                Label(L10n.deleteButton, systemImage: "trash")
            }

            Spacer()
        }
        .controlSize(.small)
    }

    private var nameRow: some View {
        HStack(spacing: 8) {
            Text(L10n.nameLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("", text: scriptNameBinding)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)
            Spacer()
            if model.selectedScript != nil {
                Text(L10n.parsedInfo(count: model.itemCount, duration: model.durationText))
                    .font(.caption)
                    .foregroundStyle(model.parseError == nil ? .green : .red)
            }
            Button(L10n.saveButton) {
                model.saveNow()
            }
            .keyboardShortcut("s", modifiers: .command)
        }
    }

    private var parseInfoRow: some View {
        HStack(spacing: 8) {
            if let error = model.parseError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else {
                Label(L10n.syntaxOk, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            Spacer()
            if let saved = model.lastSavedAt {
                Text(L10n.autoSaved(at: saved.formatted(date: .omitted, time: .standard)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Button(L10n.resetTemplateButton) {
                model.resetSelectedScriptToTemplate()
            }
            .controlSize(.small)
        }
        .font(.caption)
    }

    private var scriptTextBinding: Binding<String> {
        Binding(
            get: { model.selectedScript?.text ?? "" },
            set: { model.updateSelectedScriptText($0) }
        )
    }

    private var scriptNameBinding: Binding<String> {
        Binding(
            get: { model.selectedScript?.name ?? "" },
            set: { model.renameSelectedScript($0) }
        )
    }
}
