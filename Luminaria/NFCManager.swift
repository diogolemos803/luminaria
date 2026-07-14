import CoreNFC
import Combine

/// Lê tags NFC (NDEF), vincula a primeira tag lida e reconhece a mesma tag nas próximas leituras.
final class NFCManager: NSObject, ObservableObject {
    @Published var isLinked: Bool = false
    @Published var linkedTagID: String?
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?

    /// Chamado quando a tag vinculada é reconhecida novamente (uso: disparar o Atalho).
    var onRecognizedTap: (() -> Void)?

    private var session: NFCNDEFReaderSession?
    private let linkedTagKey = "com.luminaria.linkedTagID"

    override init() {
        super.init()
        linkedTagID = UserDefaults.standard.string(forKey: linkedTagKey)
        isLinked = linkedTagID != nil
    }

    func beginScanning() {
        errorMessage = nil
        guard NFCNDEFReaderSession.readingAvailable else {
            errorMessage = "Este iPhone não tem suporte a leitura NFC."
            return
        }
        session?.invalidate()
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = isLinked
            ? "Aproxime o iPhone da luminária"
            : "Aproxime o iPhone da luminária para vincular"
        session?.begin()
    }

    func stopScanning() {
        session?.invalidate()
    }

    func unlink() {
        UserDefaults.standard.removeObject(forKey: linkedTagKey)
        linkedTagID = nil
        isLinked = false
    }

    private func identifier(for tag: NFCNDEFTag) -> String {
        if let mifareTag = tag as? NFCMiFareTag {
            return mifareTag.identifier.map { String(format: "%02X", $0) }.joined()
        } else if let iso15693Tag = tag as? NFCISO15693Tag {
            return iso15693Tag.identifier.map { String(format: "%02X", $0) }.joined()
        } else if let iso7816Tag = tag as? NFCISO7816Tag {
            return iso7816Tag.identifier.map { String(format: "%02X", $0) }.joined()
        } else if let felicaTag = tag as? NFCFeliCaTag {
            return felicaTag.currentIDm.map { String(format: "%02X", $0) }.joined()
        } else {
            return UUID().uuidString
        }
    }

    private func handleDetectedTag(_ tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        session.connect(to: tag) { [weak self] error in
            guard let self else { return }
            if let error {
                session.invalidate(errorMessage: "Falha ao conectar: \(error.localizedDescription)")
                return
            }
            let tagID = self.identifier(for: tag)

            DispatchQueue.main.async {
                if self.isLinked {
                    if self.linkedTagID == tagID {
                        session.alertMessage = "Luminária reconhecida!"
                        session.invalidate()
                        self.statusMessage = "Luminária reconhecida"
                        self.onRecognizedTap?()
                    } else {
                        session.invalidate(errorMessage: "Esta tag não é a luminária vinculada.")
                    }
                } else {
                    UserDefaults.standard.set(tagID, forKey: self.linkedTagKey)
                    self.linkedTagID = tagID
                    self.isLinked = true
                    self.statusMessage = "Luminária vinculada com sucesso"
                    session.alertMessage = "Luminária vinculada!"
                    session.invalidate()
                }
            }
        }
    }
}

extension NFCManager: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            if let nfcError = error as? NFCReaderError,
               nfcError.code == .readerSessionInvalidationErrorUserCanceled ||
               nfcError.code == .readerSessionInvalidationErrorFirstNDEFTagRead {
                return
            }
            self.errorMessage = error.localizedDescription
        }
    }

    // Método exigido pelo protocolo; a leitura de fato é tratada em didDetect(tags:).
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {}

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else { return }
        handleDetectedTag(tag, session: session)
    }
}
