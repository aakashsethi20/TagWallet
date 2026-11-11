import CoreNFC

final class ScanReader: NSObject, NFCTagReaderSessionDelegate {
    var session: NFCTagReaderSession?
    var completion: ((Result<TagDump, Error>) -> Void)?
    var handling = false
    func start(_ completion: @escaping (Result<TagDump, Error>) -> Void) {
        guard NFCTagReaderSession.readingAvailable else { completion(.failure(WalletFailure("Scanning requires a supported iPhone."))); return }
        self.completion = completion; handling = false
        session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: .main)
        session?.alertMessage = "Hold one NTAG215 tag to the top of your phone."; session?.begin()
    }
    func finish(_ result: Result<TagDump, Error>) {
        DispatchQueue.main.async {
            guard let callback = self.completion else { return }
            self.completion = nil; self.session?.invalidate(); self.session = nil; callback(result)
        }
    }
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) { if self.session === session { finish(.failure(error)) } }
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard !handling else { return }
        guard tags.count == 1, let first = tags.first, case .miFare(let tag) = first else { session.alertMessage = "Present exactly one NTAG215 tag."; session.restartPolling(); return }
        handling = true
        session.connect(to: first) { error in
            if let error = error { self.finish(.failure(error)); return }
            NTAG215Tag.initialize(tag: tag) { result in self.finish(result.map { $0.dump }) }
        }
    }
}
