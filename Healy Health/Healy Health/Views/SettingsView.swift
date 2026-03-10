import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: RoutineStore
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var isImporting = false
    @State private var showImportSuccessAlert = false
    @State private var showImportErrorAlert = false
    
    private var totalWorkoutsCompleted: Int {
        store.completedWorkouts.count
    }
    
    var body: some View {
        Form {
            Section(header: Text("Your stats").foregroundColor(.white)) {
                HStack {
                    Text("Total Workouts Completed")
                    Spacer()
                    Text("\(totalWorkoutsCompleted)")
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color.white)
            }
            
            Section(header: Text("App appearance").foregroundColor(.white)) {
                HStack {
                    Text("Theme")
                    Spacer()
                    Text("System Blue")
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color.white)
            }
            
            Section(header: Text("Data Management").foregroundColor(.white)) {
                Button(action: {
                    if let url = ExportManager.shared.generateJSONData() {
                        exportURL = url
                        showShareSheet = true
                    }
                }) {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
                .listRowBackground(Color.white)
                
                Button(action: {
                    isImporting = true
                }) {
                    Label("Import Data", systemImage: "square.and.arrow.down")
                        .foregroundColor(.blue)
                }
                .listRowBackground(Color.white)
            }
            
            Section(header: Text("About").foregroundColor(.white)) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0 (Beta)")
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color.white)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.blue.ignoresSafeArea())
        .navigationTitle("Settings")
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [UTType.json]) { result in
            switch result {
            case .success(let fileURL):
                // Ensure we have access to the file
                guard fileURL.startAccessingSecurityScopedResource() else {
                    showImportErrorAlert = true
                    return
                }
                defer { fileURL.stopAccessingSecurityScopedResource() }
                
                if ExportManager.shared.importJSONData(from: fileURL) {
                    showImportSuccessAlert = true
                } else {
                    showImportErrorAlert = true
                }
            case .failure(let error):
                print(error.localizedDescription)
                showImportErrorAlert = true
            }
        }
        .alert("Import Successful", isPresented: $showImportSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your app data has been fully restored.")
        }
        .alert("Import Failed", isPresented: $showImportErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The file selected was invalid or could not be read.")
        }
    }
}
