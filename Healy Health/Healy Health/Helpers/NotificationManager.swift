import Foundation
import UserNotifications

enum RestTimerDuration {
    static let maximumSeconds: TimeInterval = 24 * 60 * 60

    static func validate(_ seconds: TimeInterval) -> Result<TimeInterval, RestTimerNotificationError> {
        guard seconds.isFinite, seconds > 0 else {
            return .failure(.invalidDuration)
        }
        guard seconds <= maximumSeconds else {
            return .failure(.durationTooLong(maximumSeconds: maximumSeconds))
        }
        return .success(seconds)
    }
}

enum RestTimerNotificationError: LocalizedError, Equatable {
    case invalidDuration
    case durationTooLong(maximumSeconds: TimeInterval)
    case permissionDenied
    case schedulingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            return "Enter a rest duration greater than zero seconds."
        case let .durationTooLong(maximumSeconds):
            return "Enter a rest duration of " + String(Int(maximumSeconds / 60 / 60)) + " hours or less."
        case .permissionDenied:
            return "The countdown is running, but its completion notification is turned off. You can enable notifications for Healy Health in Settings."
        case .schedulingFailed:
            return "The countdown is running, but its completion notification could not be scheduled."
        }
    }
}

final class NotificationManager {
    static let shared = NotificationManager()

    private static let timerIdentifierPrefix = "restTimer-"

    private let authorizationStatusProvider: (@escaping (UNAuthorizationStatus) -> Void) -> Void
    private let authorizationRequester: (@escaping (Bool, Error?) -> Void) -> Void
    private let requestAdder: (UNNotificationRequest, @escaping (Error?) -> Void) -> Void
    private let timerCanceler: ([String]) -> Void
    private let cancellationLock = NSLock()
    private var cancelledTimerIDs = Set<UUID>()

    init(
        authorizationStatusProvider: @escaping (@escaping (UNAuthorizationStatus) -> Void) -> Void = { completion in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                completion(settings.authorizationStatus)
            }
        },
        authorizationRequester: @escaping (@escaping (Bool, Error?) -> Void) -> Void = { completion in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge], completionHandler: completion)
        },
        requestAdder: @escaping (UNNotificationRequest, @escaping (Error?) -> Void) -> Void = { request, completion in
            UNUserNotificationCenter.current().add(request, withCompletionHandler: completion)
        },
        timerCanceler: @escaping ([String]) -> Void = { identifiers in
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    ) {
        self.authorizationStatusProvider = authorizationStatusProvider
        self.authorizationRequester = authorizationRequester
        self.requestAdder = requestAdder
        self.timerCanceler = timerCanceler
    }

    @discardableResult
    func scheduleTimer(
        seconds: TimeInterval,
        identifier: UUID = UUID(),
        completion: @escaping (Result<Void, RestTimerNotificationError>) -> Void
    ) -> UUID {
        switch RestTimerDuration.validate(seconds) {
        case .failure(let error):
            complete(completion, with: .failure(error))
            return identifier
        case .success(let validSeconds):
            markScheduled(identifier)
            scheduleTimerNotification(seconds: validSeconds, identifier: identifier, completion: completion)
            return identifier
        }
    }

    private func scheduleTimerNotification(
        seconds: TimeInterval,
        identifier: UUID,
        completion: @escaping (Result<Void, RestTimerNotificationError>) -> Void
    ) {
        authorizationStatusProvider { [weak self] status in
            guard let self else { return }
            guard !self.isCancelled(identifier) else { return }
            switch status {
            case .authorized, .provisional, .ephemeral:
                self.addTimer(seconds: seconds, identifier: identifier, completion: completion)
            case .notDetermined:
                self.authorizationRequester { granted, error in
                    guard !self.isCancelled(identifier) else { return }
                    if let error {
                        self.complete(completion, with: .failure(.schedulingFailed(error.localizedDescription)))
                    } else if granted {
                        self.addTimer(seconds: seconds, identifier: identifier, completion: completion)
                    } else {
                        self.complete(completion, with: .failure(.permissionDenied))
                    }
                }
            case .denied:
                self.complete(completion, with: .failure(.permissionDenied))
            @unknown default:
                self.complete(completion, with: .failure(.permissionDenied))
            }
        }
    }

    private func addTimer(
        seconds: TimeInterval,
        identifier: UUID,
        completion: @escaping (Result<Void, RestTimerNotificationError>) -> Void
    ) {
        guard !isCancelled(identifier) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Rest Complete"
        content.body = "Your rest timer is done. Time for the next set!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: timerNotificationIdentifier(identifier), content: content, trigger: trigger)

        requestAdder(request) { [weak self] error in
            guard let self else { return }
            if self.isCancelled(identifier) {
                self.timerCanceler([self.timerNotificationIdentifier(identifier)])
                return
            }
            if let error {
                self.complete(completion, with: .failure(.schedulingFailed(error.localizedDescription)))
            } else {
                self.complete(completion, with: .success(()))
            }
        }
    }

    private func complete(
        _ completion: @escaping (Result<Void, RestTimerNotificationError>) -> Void,
        with result: Result<Void, RestTimerNotificationError>
    ) {
        DispatchQueue.main.async {
            completion(result)
        }
    }

    func cancelTimer(identifier: UUID) {
        cancellationLock.lock()
        cancelledTimerIDs.insert(identifier)
        cancellationLock.unlock()
        timerCanceler([timerNotificationIdentifier(identifier)])
    }

    /// Removes orphaned rest-timer notifications while preserving the one restored with the
    /// active session, if any. This keeps pre-persistence notifications from firing later.
    func cancelPendingTimers(except activeTimerID: UUID? = nil) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let activeRequestID = activeTimerID.map(self.timerNotificationIdentifier)
            let timerIDs = requests.map(\.identifier).filter {
                $0.hasPrefix(Self.timerIdentifierPrefix) && $0 != activeRequestID
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: timerIDs)
        }
    }

    private func markScheduled(_ identifier: UUID) {
        cancellationLock.lock()
        cancelledTimerIDs.remove(identifier)
        cancellationLock.unlock()
    }

    private func isCancelled(_ identifier: UUID) -> Bool {
        cancellationLock.lock()
        defer { cancellationLock.unlock() }
        return cancelledTimerIDs.contains(identifier)
    }

    private func timerNotificationIdentifier(_ identifier: UUID) -> String {
        Self.timerIdentifierPrefix + identifier.uuidString
    }
}
