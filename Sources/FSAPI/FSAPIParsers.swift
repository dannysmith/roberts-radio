import Foundation

// MARK: - XML Parsing

/// Parses a GET response: <fsapiResponse><status>X</status><value><TYPE>V</TYPE></value></fsapiResponse>
final class FSAPIGetParser: NSObject, XMLParserDelegate {
    private(set) var status = ""
    private(set) var value: String?
    private var path: [String] = []
    private var text = ""

    static func parse(_ data: Data) -> (status: String, value: String?) {
        let handler = FSAPIGetParser()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        parser.parse()
        return (handler.status, handler.value)
    }

    func parser(_: XMLParser, didStartElement name: String,
                namespaceURI _: String?, qualifiedName _: String?,
                attributes _: [String: String] = [:]) {
        path.append(name)
        text = ""
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_: XMLParser, didEndElement name: String,
                namespaceURI _: String?, qualifiedName _: String?) {
        defer { path.removeLast() }
        let parent = path.count >= 2 ? path[path.count - 2] : ""
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if name == "status", parent == "fsapiResponse" {
            status = t
        } else if parent == "value" {
            value = t
        }
    }
}

/// Parses the `/device` description: <netRemote><webfsapi>http://host:80/fsapi</webfsapi></netRemote>
final class FSAPIDeviceParser: NSObject, XMLParserDelegate {
    private var path: [String] = []
    private var text = ""
    private var webfsapi: String?

    /// Returns the device's FSAPI URL, or nil if the response isn't from an FSAPI device.
    static func fsapiURL(from data: Data) -> URL? {
        let handler = FSAPIDeviceParser()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        guard parser.parse(), let value = handler.webfsapi, let url = URL(string: value),
              url.scheme == "http" || url.scheme == "https", url.path == "/fsapi"
        else { return nil }
        return url
    }

    func parser(_: XMLParser, didStartElement name: String,
                namespaceURI _: String?, qualifiedName _: String?,
                attributes _: [String: String] = [:]) {
        path.append(name)
        text = ""
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_: XMLParser, didEndElement _: String,
                namespaceURI _: String?, qualifiedName _: String?) {
        if path == ["netRemote", "webfsapi"] {
            webfsapi = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        path.removeLast()
    }
}

/// Parses LIST_GET_NEXT: items with key attribute and named fields
final class FSAPIListParser: NSObject, XMLParserDelegate {
    struct Item {
        let key: Int
        var fields: [String: String]

        /// Navigation lists use type 255 for rows that are still loading from the cloud.
        var isLoadingPlaceholder: Bool {
            fields["type"] == "255"
        }
    }

    private(set) var status = ""
    private(set) var items: [Item] = []
    private var reachedEnd = false
    private var path: [String] = []
    private var text = ""
    private var itemKey: Int?
    private var itemFields: [String: String] = [:]
    private var fieldName: String?

    static func parse(_ data: Data) -> (status: String, items: [Item], reachedEnd: Bool) {
        let handler = FSAPIListParser()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        parser.parse()
        return (handler.status, handler.items, handler.reachedEnd)
    }

    func parser(_: XMLParser, didStartElement name: String,
                namespaceURI _: String?, qualifiedName _: String?,
                attributes: [String: String] = [:]) {
        path.append(name)
        text = ""
        if name == "item" {
            itemKey = Int(attributes["key"] ?? "")
            itemFields = [:]
        } else if name == "field" {
            fieldName = attributes["name"]
        } else if name == "listend" {
            reachedEnd = true
        }
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_: XMLParser, didEndElement name: String,
                namespaceURI _: String?, qualifiedName _: String?) {
        defer { path.removeLast() }
        let parent = path.count >= 2 ? path[path.count - 2] : ""
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if name == "status", parent == "fsapiResponse" {
            status = t
        } else if parent == "field", let fn = fieldName {
            itemFields[fn] = t
        } else if name == "item", let k = itemKey {
            items.append(Item(key: k, fields: itemFields))
        }
    }
}

/// Parses GET_MULTIPLE: multiple <fsapiResponse> blocks inside <fsapiGetMultipleResponse>
final class FSAPIMultiParser: NSObject, XMLParserDelegate {
    private(set) var values: [String: String] = [:]
    private var path: [String] = []
    private var text = ""
    private var curNode = ""
    private var curStatus = ""
    private var curValue = ""

    static func parse(_ data: Data) -> [String: String] {
        let handler = FSAPIMultiParser()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        parser.parse()
        return handler.values
    }

    func parser(_: XMLParser, didStartElement name: String,
                namespaceURI _: String?, qualifiedName _: String?,
                attributes _: [String: String] = [:]) {
        path.append(name)
        text = ""
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_: XMLParser, didEndElement name: String,
                namespaceURI _: String?, qualifiedName _: String?) {
        defer { path.removeLast() }
        let parent = path.count >= 2 ? path[path.count - 2] : ""
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (name, parent) {
        case ("status", "fsapiResponse"): curStatus = t
        case ("node", "fsapiResponse"): curNode = t
        case (_, "value"): curValue = t
        case ("fsapiResponse", _):
            if curStatus == "FS_OK", !curNode.isEmpty {
                values[curNode] = curValue
            }
            curNode = ""; curStatus = ""; curValue = ""
        default: break
        }
    }
}
