import Foundation
import SwiftUI

class ExportManager {
    static let shared = ExportManager()
    
    func generateJSONData() -> URL? {
        struct AppExportData: Codable {
            let routines: [Routine]
            let completedWorkouts: [CompletedWorkout]
        }
        
        let exportData = AppExportData(
            routines: RoutineStore.shared.routines,
            completedWorkouts: RoutineStore.shared.completedWorkouts
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(exportData)
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileURL = tempDirectory.appendingPathComponent("HealyHealth_Export.json")
            
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to export data: \(error)")
            return nil
        }
    }
    
    // Import Functionality
    func importJSONData(from url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        
        struct AppExportData: Codable {
            let routines: [Routine]
            let completedWorkouts: [CompletedWorkout]
        }
        
        do {
            let decoded = try JSONDecoder().decode(AppExportData.self, from: data)
            RoutineStore.shared.routines = decoded.routines
            RoutineStore.shared.completedWorkouts = decoded.completedWorkouts
            RoutineStore.shared.saveRoutines()
            RoutineStore.shared.saveHistory()
            return true
        } catch {
            print("Failed to import data: \(error)")
            return false
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
