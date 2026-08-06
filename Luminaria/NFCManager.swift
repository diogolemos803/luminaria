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
    /// Chamado quando a sessão termina SEM reconhecer a tag vinculada (cancelou, deu
    /// timeout dos ~60s do CoreNFC, ou encostou a tag errada) — usado pra desarmar o
    /// modo noite automaticamente em vez de deixar o app preso num estado "armado" que
    /// nunca vai disparar nada.
    var onScanEndedWithoutMatch: (() -> Void)?

    private var session: NFCNDEFReaderSession?
    private let linkedTagKey = "com.luminaria.linkedTagID"
    private var recognizedThisSession = false

    override init() {
        super.init()
        linkedTagID = UserDefaults.standard.string(forKey: linkedTagKey)
        isLinked = linkedTagID != nil
    }

    func beginScanning() {
        errorMessage = nil
        recognizedThisSession = false
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
        // Downcast direto do protocolo (`tag as? NFCMiFareTag`) falha num build de
        // Release/distribuição — confirmado no device via TestFlight (`type(of: tag)`
        // retornava só "NFCNDEFTag", o próprio protocolo, nunca a classe concreta).
        // Passar por `AnyObject` primeiro força o cast a usar o runtime do Objective-C
        // (`isKindOfClass:`) em vez do mecanismo de protocolo do Swift, que é o fix
        // documentado pra esse problema conhecido do CoreNFC.
        let object = tag as AnyObject
        if let mifareTag = object as? NFCMiFareTag {
            return mifareTag.identifier.map { String(format: "%02X", $0) }.joined()
        } else if let iso15693Tag = object as? NFCISO15693Tag {
            return iso15693Tag.identifier.map { String(format: "%02X", $0) }.joined()
        } else if let iso7816Tag = object as? NFCISO7816Tag {
            return iso7816Tag.identifier.map { String(format: "%02X", $0) }.joined()
        } else if let felicaTag = object as? NFCFeliCaTag {
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

            DispatchQueue.main.async {
                self.recognizedThisSession = true
                if self.isLinked {
                    // Não compara mais o ID da tag com a vinculada — depois de vincular
                    // uma vez (o que já mantém a trava de "inútil sem luminária"),
                    // qualquer tag NFC reconhecida dispara o modo noite. Decisão do
                    // usuário pra simplificar, depois de identificar (e corrigir) um bug
                    // real de downcast de `NFCNDEFTag` em build de distribuição que
                    // tornava a comparação de ID pouco confiável.
                    session.alertMessage = "Luminária reconhecida!"
                    session.invalidate()
                    self.statusMessage = "Luminária reconhecida"
                    self.onRecognizedTap?()
                } else {
                    let tagID = self.identifier(for: tag)
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
            // Sessão terminou sem reconhecer a tag vinculada (cancelou, timeout dos
            // ~60s do CoreNFC, ou tag errada) — desarma o modo noite pelo mesmo motivo
            // documentado no app: só fica armado se a leitura realmente for concluída.
            if !self.recognizedThisSession {
                self.onScanEndedWithoutMatch?()
            }
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
