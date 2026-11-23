import Foundation

/// A radio that has proven its identity over FSAPI.
struct RadioIdentity: Equatable, Sendable {
    let host: String
    let radioID: String
    let name: String
}

enum RadioVerification: Equatable, Sendable {
    case verified(RadioIdentity)
    case wrongPIN(host: String)
    case notARadio
}

/// Checks whether a host is an FSAPI radio. The PIN is only sent once the host has identified itself as FSAPI.
struct RadioVerifier: Sendable {
    let pin: String

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1.5
        configuration.timeoutIntervalForResource = 3
        return URLSession(configuration: configuration)
    }()

    func verify(host: String) async -> RadioVerification {
        guard await identifiesAsFSAPI(host) else { return .notARadio }

        let nodes = "node=netRemote.sys.info.radioId&node=netRemote.sys.info.friendlyName"
        guard let url = URL(string: "http://\(host)/fsapi/GET_MULTIPLE?pin=\(pin)&\(nodes)"),
              let (data, response) = try? await Self.session.data(from: url),
              let status = (response as? HTTPURLResponse)?.statusCode
        else { return .notARadio }

        if status == 403 {
            return .wrongPIN(host: host)
        }
        let values = FSAPIMultiParser.parse(data)
        guard let radioID = values["netRemote.sys.info.radioId"], !radioID.isEmpty else { return .notARadio }
        return .verified(RadioIdentity(
            host: host,
            radioID: radioID,
            name: values["netRemote.sys.info.friendlyName"] ?? "",
        ))
    }

    private func identifiesAsFSAPI(_ host: String) async -> Bool {
        guard let url = URL(string: "http://\(host)/device"),
              let (data, response) = try? await Self.session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return false }
        return FSAPIDeviceParser.fsapiURL(from: data) != nil
    }
}
