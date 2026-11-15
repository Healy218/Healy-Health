import SwiftUI

// MARK: - Timer Preset Button

struct TimerPresetButton: View {
    let duration: Double
    let label: String
    @Binding var selectedDuration: Double
    @EnvironmentObject var themeManager: ThemeManager

    var isSelected: Bool { selectedDuration == duration }
    private var theme: AppTheme { themeManager.current }

    var body: some View {
        Button(action: { selectedDuration = duration }) {
            Text(label)
                .font(.caption).fontWeight(.bold)
                .frame(minWidth: 62, minHeight: 44)
                .background(isSelected ? theme.primaryActionBackgroundColor : theme.primaryColor.opacity(0.5))
                .foregroundColor(isSelected ? theme.primaryActionTextColor : theme.onPrimaryText)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.onPrimaryText, lineWidth: 1))
        }
        .accessibilityLabel("Rest timer duration \(spokenDuration)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Sets the automatic rest timer after logging a set.")
    }

    private var spokenDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if seconds == 0 { return "\(minutes) minute\(minutes == 1 ? "" : "s")" }
        return "\(minutes) minutes \(seconds) seconds"
    }
}

struct CustomTimerPresetButton: View {
    @Binding var isPresented: Bool
    let isSelected: Bool
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        Button(action: { isPresented = true }) {
            Text("Custom")
                .font(.caption).fontWeight(.bold)
                .frame(minWidth: 62, minHeight: 44)
                .background(isSelected ? theme.primaryActionBackgroundColor : theme.primaryColor.opacity(0.5))
                .foregroundColor(isSelected ? theme.primaryActionTextColor : theme.onPrimaryText)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.onPrimaryText, lineWidth: 1))
        }
        .accessibilityLabel("Custom rest timer duration")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Enter a duration in seconds.")
    }
}

// MARK: - Set Input View

struct SetInputView: View {
    let setNumber: Int
    @Binding var weightInput: String
    @Binding var repsInput: String
    @Binding var selectedDuration: Double
    @Binding var showCustomTimerAlert: Bool
    var isCustomDuration: Bool
    var validationMessage: String?
    var onLogSet: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage(WeightUnit.storageKey) private var weightUnit: WeightUnit = .pounds

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        VStack(spacing: 20) {
            Text("Set \(setNumber)").font(.title).foregroundColor(theme.onPrimaryText)

            ViewThatFits(in: .horizontal) {
                setInputs(axis: .horizontal)
                setInputs(axis: .vertical)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                Text("Auto-Start Timer Duration:").foregroundColor(theme.onPrimaryText).font(.caption)
                ViewThatFits(in: .horizontal) {
                    timerPresetRow
                    timerPresetGrid
                }
            }
            .padding(.horizontal)

            Button(action: onLogSet) {
                Text("Log Set").font(.headline)
                    .foregroundColor(theme.primaryActionTextColor).padding().frame(maxWidth: .infinity)
                    .background(theme.primaryActionBackgroundColor).cornerRadius(10)
            }
            .accessibilityHint("Logs set \(setNumber) and starts the selected rest timer.")
            .padding(.horizontal)

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundColor(theme.onPrimaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    @ViewBuilder
    private func setInputs(axis: Axis) -> some View {
        if axis == .horizontal {
            HStack(spacing: 20) {
                setInput(label: "Weight (\(weightUnit.symbol))", text: $weightInput, keyboard: .decimalPad)
                setInput(label: "Reps", text: $repsInput, keyboard: .numberPad)
            }
        } else {
            VStack(spacing: 12) {
                setInput(label: "Weight (\(weightUnit.symbol))", text: $weightInput, keyboard: .decimalPad)
                setInput(label: "Reps", text: $repsInput, keyboard: .numberPad)
            }
        }
    }

    private func setInput(label: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).foregroundColor(theme.onPrimaryText)
            TextField("0", text: text)
                .keyboardType(keyboard)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(theme.inputBackgroundColor)
                .foregroundColor(theme.inputTextColor)
                .cornerRadius(10)
                .accessibilityLabel(label == "Reps" ? "Repetitions for set \(setNumber)" : "Weight for set \(setNumber), \(weightUnit.spokenName)")
        }
        .frame(minWidth: 132, maxWidth: .infinity, alignment: .leading)
    }

    private var timerPresetRow: some View {
        HStack(spacing: 8) {
            TimerPresetButton(duration: 120, label: "2:00", selectedDuration: $selectedDuration)
            TimerPresetButton(duration: 150, label: "2:30", selectedDuration: $selectedDuration)
            TimerPresetButton(duration: 180, label: "3:00", selectedDuration: $selectedDuration)
            CustomTimerPresetButton(isPresented: $showCustomTimerAlert, isSelected: isCustomDuration)
        }
    }

    private var timerPresetGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
            spacing: 8
        ) {
            TimerPresetButton(duration: 120, label: "2:00", selectedDuration: $selectedDuration)
            TimerPresetButton(duration: 150, label: "2:30", selectedDuration: $selectedDuration)
            TimerPresetButton(duration: 180, label: "3:00", selectedDuration: $selectedDuration)
            CustomTimerPresetButton(isPresented: $showCustomTimerAlert, isSelected: isCustomDuration)
        }
    }
}

// MARK: - Rest Timer Display View

struct RestTimerDisplayView: View {
    let timeRemaining: TimeInterval
    let nextSetNumber: Int
    var onSkip: () -> Void
    var onAddTime: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        VStack(spacing: 20) {
            Text("Rest Timer").font(.headline).foregroundColor(theme.onPrimaryText)
            Text(timeString(time: timeRemaining))
                .font(.system(.largeTitle, design: .monospaced).weight(.bold)).foregroundColor(theme.onPrimaryText)
                .accessibilityLabel("Rest time remaining")
                .accessibilityValue(spokenTimeRemaining)
            Button(action: onSkip) {
                Text("Skip Rest & Start Set \(nextSetNumber)")
                    .foregroundColor(theme.primaryActionTextColor)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(theme.primaryActionBackgroundColor).cornerRadius(10)
            }
            .accessibilityLabel("Skip rest and start set \(nextSetNumber)")
            .accessibilityHint("Stops the rest timer.")
            Button(action: onAddTime) {
                Text("+30s")
                    .foregroundColor(theme.onPrimaryText)
                    .frame(minWidth: 44, minHeight: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.onPrimaryText, lineWidth: 1))
            }
            .accessibilityLabel("Add 30 seconds to rest timer")
            .accessibilityHint("Extends the active rest timer.")
        }
        .padding().background(Color.white.opacity(0.1)).cornerRadius(20).padding()
    }

    private func timeString(time: TimeInterval) -> String {
        let t = Int(ceil(time))
        return String(format: "%02d:%02d", t / 60, t % 60)
    }

    private var spokenTimeRemaining: String {
        let seconds = max(0, Int(ceil(timeRemaining)))
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes == 0 { return "\(remainder) seconds" }
        if remainder == 0 { return "\(minutes) minute\(minutes == 1 ? "" : "s")" }
        return "\(minutes) minute\(minutes == 1 ? "" : "s") \(remainder) seconds"
    }
}
