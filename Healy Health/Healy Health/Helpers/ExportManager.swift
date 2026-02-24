import Foundation
import SwiftUI

class ExportManager {
    static let shared = ExportManager()
    
    func generateJSONData() -> URL? {
        let schedule = WorkoutSchedule.shared.fullSchedule
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(schedule)
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileURL = tempDirectory.appendingPathComponent("HealyHealth_Export.json")
            
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to export data: \(error)")
            return nil
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
