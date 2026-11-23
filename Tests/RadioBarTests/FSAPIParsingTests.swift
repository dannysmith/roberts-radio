import Foundation
@testable import RadioBar
import Testing

/// Parses responses captured from a Roberts iStream 3L.
struct FSAPIParsingTests {
    @Test func `parses get value`() {
        let xml = """
        <fsapiResponse>
        <status>FS_OK</status>
        <value><c8_array>iStream3L</c8_array></value>
        </fsapiResponse>
        """
        let result = FSAPIGetParser.parse(Data(xml.utf8))
        #expect(result.status == "FS_OK")
        #expect(result.value == "iStream3L")
    }

    @Test func `parses get failure status`() {
        let xml = "<fsapiResponse><status>FS_NODE_BLOCKED</status></fsapiResponse>"
        let result = FSAPIGetParser.parse(Data(xml.utf8))
        #expect(result.status == "FS_NODE_BLOCKED")
        #expect(result.value == nil)
    }

    @Test func `multiple response skips failed nodes`() {
        let xml = """
        <fsapiGetMultipleResponse>
        <fsapiResponse>
        <node>netRemote.sys.power</node>
        <status>FS_OK</status>
        <value><u8>1</u8></value>
        </fsapiResponse>
        <fsapiResponse>
        <node>netRemote.play.rating</node>
        <status>FS_NODE_BLOCKED</status>
        </fsapiResponse>
        </fsapiGetMultipleResponse>
        """
        #expect(FSAPIMultiParser.parse(Data(xml.utf8)) == ["netRemote.sys.power": "1"])
    }

    @Test func `parses list items`() {
        let xml = """
        <fsapiResponse>
        <status>FS_OK</status>
        <item key="2">
        <field name="name"><c8_array>BBC Radio 4</c8_array></field>
        <field name="type"><u8>1</u8></field>
        </item>
        </fsapiResponse>
        """
        let result = FSAPIListParser.parse(Data(xml.utf8))
        #expect(result.status == "FS_OK")
        #expect(result.items.count == 1)
        #expect(result.items.first?.key == 2)
        #expect(result.items.first?.fields == ["name": "BBC Radio 4", "type": "1"])
    }
}
