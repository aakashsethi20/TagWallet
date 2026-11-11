import Foundation
import CoreNFC

protocol CardWriting: AnyObject {
    func write(_ dump: TagDump, staticKey: TagKey, dataKey: TagKey, completion: @escaping (Result<Void, Error>) -> Void)
    func cancel()
}
final class BatchWriter: NSObject, CardWriting, NFCTagReaderSessionDelegate {
    private var session: NFCTagReaderSession?
    private var completion: ((Result<Void, Error>) -> Void)?
    private var operation: (TagDump, TagKey, TagKey)?
    private var handling = false
    func write(_ dump: TagDump, staticKey: TagKey, dataKey: TagKey, completion: @escaping (Result<Void, Error>) -> Void) {
        guard self.completion == nil else { return }
        guard NFCTagReaderSession.readingAvailable else { completion(.failure(WalletFailure("NFC writing requires a supported iPhone."))); return }
        operation = (dump, staticKey, dataKey); self.completion = completion; handling = false
        session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: .main)
        session?.alertMessage = "Hold one blank NTAG215 tag to the top of your iPhone."
        session?.begin()
    }
    func cancel() { session?.invalidate(); finish(.failure(WalletFailure("Writing cancelled."))) }
    private func finish(_ result: Result<Void, Error>) {
        DispatchQueue.main.async {
            guard let callback = self.completion else { return }
            self.completion = nil; self.operation = nil; self.handling = false
            switch result {
            case .success: self.session?.alertMessage = "Tag written successfully."; self.session?.invalidate()
            case .failure(let error): self.session?.invalidate(errorMessage: error.localizedDescription)
            }
            self.session = nil; callback(result)
        }
    }
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        guard self.session === session else { return }
        finish(.failure(error))
    }
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard !handling, let operation = operation else { return }
        guard tags.count == 1, let first = tags.first, case .miFare(let tag) = first else {
            session.alertMessage = "Present exactly one NTAG215 tag."; session.restartPolling(); return
        }
        handling = true
        session.connect(to: first) { error in
            if let error = error { self.finish(.failure(error)); return }
            NTAG215Tag.initialize(tag: tag) { result in
                switch result {
                case .failure(let error): self.finish(.failure(error))
                case .success(let target):
                    guard !target.isLocked else { self.finish(.failure(WalletFailure("This tag is locked. Use a fresh blank NTAG215."))); return }
                    target.patchAndWriteDump(operation.0, staticKey: operation.1, dataKey: operation.2) { result in
                        switch result {
                        case .success: self.finish(.success(()))
                        case .failure(let error): self.finish(.failure(error))
                        }
                    }
                }
            }
        }
    }
}
