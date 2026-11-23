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

/// Parses LIST_GET_NEXT: items with key attribute and named fields
final class FSAPIListParser: NSObject, XMLParserDelegate {
    struct Item { let key: Int; var fields: [String: String] }

    private(set) var status = ""
    private(set) var items: [Item] = []
    private var path: [String] = []
    private var text = ""
    private var itemKey: Int?
    private var itemFields: [String: String] = [:]
    private var fieldName: String?

    static func parse(_ data: Data) -> (status: String, items: [Item]) {
        let handler = FSAPIListParser()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        parser.parse()
        return (handler.status, handler.items)
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
