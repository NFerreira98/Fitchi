#if canImport(WatchConnectivity)
    import FitchiCore
    import Foundation
    import Observation
    import WatchConnectivity

    /// Keeps a copy of the game on both the watch and the iPhone over WatchConnectivity, so
    /// deleting and reinstalling the watch app restores the pet instead of starting over.
    ///
    /// Each side sends its whole `GameSnapshot` after every change: as the latest application
    /// context (queued, delivered even if the other app isn't running) and, when the other
    /// device is in reach, as a message (which wakes the iPhone app) answered with the other
    /// side's copy. Merging is idempotent, so the copies settle after one round trip.
    @Observable
    @MainActor
    public final class BackupLink: NSObject {
        nonisolated static let lastBackupKey = "fitchi.lastBackup"
        nonisolated static let snapshotKey = "snapshot"

        /// When a backup last arrived from the other device.
        public private(set) var lastExchange: Date?

        private let pets: PetStore
        private let installDate: @MainActor () -> Date?
        private let adoptInstallDate: @MainActor (Date) -> Void
        private let defaults: UserDefaults
        @ObservationIgnored private var isActivated = false

        /// - Parameters:
        ///   - installDate: this device's install date, shared so Pep keeps counting from the
        ///     first install after a reinstall.
        ///   - adoptInstallDate: called with an earlier install date from the other device.
        public init(
            pets: PetStore, installDate: @escaping @MainActor () -> Date?,
            adoptInstallDate: @escaping @MainActor (Date) -> Void, defaults: UserDefaults = .standard
        ) {
            self.pets = pets
            self.installDate = installDate
            self.adoptInstallDate = adoptInstallDate
            self.defaults = defaults
            self.lastExchange = defaults.object(forKey: Self.lastBackupKey) as? Date
            super.init()
        }

        public func start() {
            guard WCSession.isSupported() else { return }
            pets.onChange { [weak self] in self?.publish() }
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }

        /// Sends this device's game to the other device.
        public func publish() {
            guard isActivated, let data = snapshotData() else { return }
            let session = WCSession.default
            #if os(iOS)
                guard session.isPaired, session.isWatchAppInstalled else { return }
            #endif
            try? session.updateApplicationContext([Self.snapshotKey: data])
            guard session.isReachable else { return }
            session.sendMessage([Self.snapshotKey: data], replyHandler: Self.replyHandler(for: self), errorHandler: nil)
        }

        /// WatchConnectivity calls reply handlers on its own queue, so the handler must not be
        /// main-actor isolated (a closure written inside a main-actor method would be, and
        /// Swift's runtime check would stop the app). It hops to the main actor itself.
        private nonisolated static func replyHandler(for link: BackupLink) -> @Sendable ([String: Any]) -> Void {
            { [weak link] reply in
                guard let data = reply[snapshotKey] as? Data else { return }
                Task { @MainActor in link?.receive(data) }
            }
        }

        private func snapshotData() -> Data? {
            guard let snapshot = pets.snapshot(installDate: installDate()) else { return nil }
            // A brand-new player with only an egg has nothing to protect yet, and sending it
            // could only ever lose to a real backup anyway.
            guard snapshot.hasPets || snapshot.starterEgg?.isHatched == true else { return nil }
            return try? snapshot.encoded()
        }

        private func receive(_ data: Data) {
            guard let backup = try? GameSnapshot.decode(data) else { return }
            if let date = backup.installDate { adoptInstallDate(date) }
            pets.restore(from: backup)
            lastExchange = Date()
            defaults.set(lastExchange, forKey: Self.lastBackupKey)
        }

        private func activated(withContext data: Data?) {
            isActivated = true
            if let data { receive(data) }
            publish()
        }
    }

    extension BackupLink: WCSessionDelegate {
        public nonisolated func session(
            _ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: (any Error)?
        ) {
            guard state == .activated else { return }
            let context = session.receivedApplicationContext[Self.snapshotKey] as? Data
            Task { @MainActor in self.activated(withContext: context) }
        }

        public nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
            guard let data = context[Self.snapshotKey] as? Data else { return }
            Task { @MainActor in self.receive(data) }
        }

        public nonisolated func session(
            _ session: WCSession, didReceiveMessage message: [String: Any],
            replyHandler: @escaping ([String: Any]) -> Void
        ) {
            let data = message[Self.snapshotKey] as? Data
            let reply = ReplyBox(replyHandler)
            Task { @MainActor in
                if let data { self.receive(data) }
                reply.send(self.snapshotData().map { [Self.snapshotKey: $0] } ?? [:])
            }
        }

        /// The other device came into range (or its app got installed): catch it up.
        public nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
            guard session.isReachable else { return }
            Task { @MainActor in self.publish() }
        }

        #if os(iOS)
            public nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
                Task { @MainActor in self.publish() }
            }

            public nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

            /// After switching watches, start talking to the new one.
            public nonisolated func sessionDidDeactivate(_ session: WCSession) {
                session.activate()
            }
        #endif
    }

    /// WatchConnectivity's reply handler isn't annotated `Sendable`, but it may be called from any
    /// thread, once.
    private struct ReplyBox: @unchecked Sendable {
        private let handler: ([String: Any]) -> Void

        init(_ handler: @escaping ([String: Any]) -> Void) {
            self.handler = handler
        }

        func send(_ reply: [String: Any]) { handler(reply) }
    }
#endif
