import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isExporting = false
    @State private var exportDocument: AppExportDocument?
    @State private var isImporting = false
    @State private var showExportSuccessAlert = false
    @State private var showExportErrorAlert = false
    @State private var showImportSuccessAlert = false
    @State private var showImportErrorAlert = false
    @State private var importErrorMessage = "The selected file could not be imported."
    @AppStorage(WeightUnit.storageKey) private var weightUnit: WeightUnit = .pounds

    private var theme: AppTheme { themeManager.current }
    private var totalWorkoutsCompleted: Int { store.completedWorkouts.count }
    private var appVersion: String {
        let bundle = Bundle.main
        guard let marketingVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String else {
            return "Unavailable"
        }
        return "\(marketingVersion) (\(buildVersion))"
    }

    var body: some View {
        Form {
            appearanceSection
            unitsSection
            statsSection
            dataManagementSection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background(theme.primaryColor.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: ExportManager.shared.defaultExportFilename()
        ) { result in
            switch result {
            case .success:
                showExportSuccessAlert = true
            case .failure:
                showExportErrorAlert = true
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [UTType.json]) { result in
            switch result {
            case .success(let url):
                guard url.startAccessingSecurityScopedResource() else {
                    importErrorMessage = "The selected file could not be accessed."
                    showImportErrorAlert = true
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                switch ExportManager.shared.importJSONData(from: url) {
                case .success:
                    showImportSuccessAlert = true
                case .failure(let error):
                    importErrorMessage = error.localizedDescription
                    showImportErrorAlert = true
                }
            case .failure:
                importErrorMessage = "The selected file could not be accessed."
                showImportErrorAlert = true
            }
        }
        .alert("Export Successful", isPresented: $showExportSuccessAlert) { Button("OK", role: .cancel) { } }
            message: { Text("Your data was exported as a JSON file. Save it to Files, ideally in iCloud Drive, so it is available on this Mac and can be imported on the new phone.") }
        .alert("Export Failed", isPresented: $showExportErrorAlert) { Button("OK", role: .cancel) { } }
            message: { Text("The app could not create or save the export file.") }
        .alert("Import Successful", isPresented: $showImportSuccessAlert) { Button("OK", role: .cancel) { } }
            message: { Text("Your app data has been fully restored.") }
        .alert("Import Failed", isPresented: $showImportErrorAlert) { Button("OK", role: .cancel) { } }
            message: { Text(importErrorMessage) }
    }

    private var appearanceSection: some View {
        Section(header: Text("Appearance").foregroundColor(theme.onPrimaryText)) {
            NavigationLink(destination: ThemePickerView()) {
                HStack {
                    Text("Theme").foregroundColor(theme.rowText)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(theme.primaryColor)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        Text(theme.displayName)
                            .foregroundColor(theme.secondaryRowText)
                    }
                }
            }
            .listRowBackground(theme.rowBackground)
        }
    }

    private var statsSection: some View {
        Section(header: Text("Your Stats").foregroundColor(theme.onPrimaryText)) {
            HStack {
                Text("Total Workouts Completed").foregroundColor(theme.rowText)
                Spacer()
                Text("\(totalWorkoutsCompleted)").foregroundColor(theme.secondaryRowText)
            }
            .listRowBackground(theme.rowBackground)
        }
    }

    private var unitsSection: some View {
        Section {
            Picker("Weight Unit", selection: $weightUnit) {
                ForEach(WeightUnit.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
            .foregroundColor(theme.rowText)
            .listRowBackground(theme.rowBackground)
        } header: {
            Text("Units").foregroundColor(theme.onPrimaryText)
        } footer: {
            Text("Changing units only changes how weights are shown and entered. Your saved workout data remains unchanged.")
        }
    }

    private var dataManagementSection: some View {
        Section {
            Button(action: exportData) {
                Label("Export Data", systemImage: "square.and.arrow.up").foregroundColor(theme.accentColor)
            }
            .listRowBackground(theme.rowBackground)

            Button(action: { isImporting = true }) {
                Label("Import Data", systemImage: "square.and.arrow.down").foregroundColor(theme.accentColor)
            }
            .listRowBackground(theme.rowBackground)

            NavigationLink(destination: ImportBackupsView()) {
                Label("Restore Pre-Import Backup", systemImage: "clock.arrow.circlepath")
                    .foregroundColor(theme.accentColor)
            }
            .listRowBackground(theme.rowBackground)
        } header: {
            Text("Data Management").foregroundColor(theme.onPrimaryText)
        } footer: {
            Text("Before every import, DERD Health saves your current data as a dated pre-import backup. Restore one here if an import needs to be undone.")
        }
    }

    private var aboutSection: some View {
        Section(header: Text("About").foregroundColor(theme.onPrimaryText)) {
            VStack(alignment: .leading, spacing: 3) {
                Text("DERD Health")
                    .foregroundColor(theme.rowText)
                Text("Do Everything Right Daily")
                    .font(.footnote)
                    .foregroundColor(theme.secondaryRowText)
            }
            .listRowBackground(theme.rowBackground)

            HStack {
                Text("Version").foregroundColor(theme.rowText)
                Spacer()
                Text(appVersion).foregroundColor(theme.secondaryRowText)
            }
            .listRowBackground(theme.rowBackground)
        }
    }

    private func exportData() {
        exportDocument = ExportManager.shared.makeExportDocument()
        if exportDocument != nil {
            isExporting = true
        } else {
            showExportErrorAlert = true
        }
    }
}

struct ImportBackupsView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var backups: [ImportBackup] = []
    @State private var selectedBackup: ImportBackup?
    @State private var restoreErrorMessage: String?
    @State private var showRestoreSuccess = false

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        ZStack {
            theme.primaryColor.ignoresSafeArea()
            List {
                Section {
                    if backups.isEmpty {
                        Text("No pre-import backups are available yet.")
                            .foregroundColor(theme.secondaryRowText)
                            .listRowBackground(theme.rowBackground)
                    } else {
                        ForEach(backups) { backup in
                            Button {
                                selectedBackup = backup
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(backup.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .foregroundColor(theme.rowText)
                                        Text(backup.filename)
                                            .font(.caption)
                                            .foregroundColor(theme.secondaryRowText)
                                    }
                                    Spacer()
                                    Text("Restore")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(theme.accentColor)
                                }
                            }
                            .listRowBackground(theme.rowBackground)
                        }
                    }
                } footer: {
                    Text("Restoring uses the same validation as Import Data and saves your current app state as a new backup first.")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Pre-Import Backups")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reloadBackups)
        .confirmationDialog(
            "Restore This Backup?",
            isPresented: Binding(
                get: { selectedBackup != nil },
                set: { if !$0 { selectedBackup = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Restore Backup", role: .destructive, action: restoreSelectedBackup)
            Button("Cancel", role: .cancel) { selectedBackup = nil }
        } message: {
            Text("Your current data will first be saved as a new pre-import backup. The selected backup will then replace the active app data.")
        }
        .alert("Backup Restored", isPresented: $showRestoreSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The selected backup is now active. Your previous app data was saved as a new pre-import backup.")
        }
        .alert("Couldn’t Restore Backup", isPresented: Binding(
            get: { restoreErrorMessage != nil },
            set: { if !$0 { restoreErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { restoreErrorMessage = nil }
        } message: {
            Text(restoreErrorMessage ?? "")
        }
    }

    private func reloadBackups() {
        backups = ExportManager.shared.importBackups(in: store.persistenceDirectory)
    }

    private func restoreSelectedBackup() {
        guard let backup = selectedBackup else { return }
        selectedBackup = nil
        switch ExportManager.shared.restoreImportBackup(backup) {
        case .success:
            reloadBackups()
            showRestoreSuccess = true
        case .failure(let error):
            restoreErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Theme Picker View

struct ThemePickerView: View {
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: AppTheme { themeManager.current }
    private var styleThemes: [AppTheme] { AppTheme.allCases.filter { $0.isStyle } }
    private var colorThemes: [AppTheme] { AppTheme.allCases.filter { !$0.isStyle } }

    var body: some View {
        ZStack {
            theme.primaryColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Style section
                    themeGroup(title: "Style", themes: styleThemes, columns: 3)

                    // Color section
                    themeGroup(title: "Colors", themes: colorThemes, columns: 4)
                }
                .padding()
            }
        }
        .navigationTitle("Choose Theme")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func themeGroup(title: String, themes: [AppTheme], columns: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(AppTypography.chalkboard(16, relativeTo: .body))
                .foregroundColor(theme.secondaryOnPrimaryText)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns), spacing: 16) {
                ForEach(themes, id: \.self) { t in
                    themeCell(t)
                }
            }
        }
        .padding()
        .background(theme.onPrimaryText.opacity(0.08))
        .cornerRadius(18)
    }

    @ViewBuilder
    private func themeCell(_ t: AppTheme) -> some View {
        let isSelected = themeManager.current == t
        Button(action: { themeManager.current = t }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(t.primaryColor)
                        .frame(width: 56, height: 56)
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                        .overlay(
                            Circle().stroke(
                                isSelected ? theme.onPrimaryText : Color.clear,
                                lineWidth: 3
                            )
                        )
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(t.onPrimaryText)
                    }
                }
                Text(t.displayName)
                    .font(AppTypography.chalkboard(13, relativeTo: .footnote))
                    .foregroundColor(isSelected ? theme.onPrimaryText : theme.secondaryOnPrimaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(t.displayName) theme")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Applies this theme.")
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}
