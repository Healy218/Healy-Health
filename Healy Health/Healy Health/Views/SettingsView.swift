import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: RoutineStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var isImporting = false
    @State private var showImportSuccessAlert = false
    @State private var showImportErrorAlert = false

    private var theme: AppTheme { themeManager.current }
    private var totalWorkoutsCompleted: Int { store.completedWorkouts.count }

    var body: some View {
        Form {
            // MARK: Appearance
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

            // MARK: Stats
            Section(header: Text("Your Stats").foregroundColor(theme.onPrimaryText)) {
                HStack {
                    Text("Total Workouts Completed").foregroundColor(theme.rowText)
                    Spacer()
                    Text("\(totalWorkoutsCompleted)").foregroundColor(theme.secondaryRowText)
                }
                .listRowBackground(theme.rowBackground)
            }

            // MARK: Data Management
            Section(header: Text("Data Management").foregroundColor(theme.onPrimaryText)) {
                Button(action: {
                    if let url = ExportManager.shared.generateJSONData() { exportURL = url; showShareSheet = true }
                }) {
                    Label("Export Data", systemImage: "square.and.arrow.up").foregroundColor(theme.accentColor)
                }
                .listRowBackground(theme.rowBackground)

                Button(action: { isImporting = true }) {
                    Label("Import Data", systemImage: "square.and.arrow.down").foregroundColor(theme.accentColor)
                }
                .listRowBackground(theme.rowBackground)
            }

            // MARK: About
            Section(header: Text("About").foregroundColor(theme.onPrimaryText)) {
                HStack {
                    Text("Version").foregroundColor(theme.rowText)
                    Spacer()
                    Text("1.0 (Beta)").foregroundColor(theme.secondaryRowText)
                }
                .listRowBackground(theme.rowBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.primaryColor.ignoresSafeArea())
        .navigationTitle("Settings")
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL { ShareSheet(items: [url]) }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [UTType.json]) { result in
            switch result {
            case .success(let url):
                guard url.startAccessingSecurityScopedResource() else { showImportErrorAlert = true; return }
                defer { url.stopAccessingSecurityScopedResource() }
                if ExportManager.shared.importJSONData(from: url) { showImportSuccessAlert = true } else { showImportErrorAlert = true }
            case .failure: showImportErrorAlert = true
            }
        }
        .alert("Import Successful", isPresented: $showImportSuccessAlert) { Button("OK", role: .cancel) { } }
            message: { Text("Your app data has been fully restored.") }
        .alert("Import Failed", isPresented: $showImportErrorAlert) { Button("OK", role: .cancel) { } }
            message: { Text("The file selected was invalid or could not be read.") }
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
                .font(.custom("ChalkboardSE-Regular", size: 16))
                .foregroundColor(theme.onPrimaryText.opacity(0.75))

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
                    .font(.custom("ChalkboardSE-Regular", size: 13))
                    .foregroundColor(isSelected ? theme.onPrimaryText : theme.onPrimaryText.opacity(0.65))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}
