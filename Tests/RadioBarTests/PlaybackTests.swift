import Foundation
@testable import RadioBar
import Testing

struct PlayCapsTests {
    /// Reported by the radio while playing a live Internet Radio station.
    private let liveStream = PlayCaps(rawValue: 2050)

    @Test func `decodes live stream capabilities`() {
        #expect(liveStream.contains(.stop))
        #expect(!liveStream.contains(.pause))
        #expect(!liveStream.contains(.seek))
        #expect(!liveStream.canSkipNext)
        #expect(!liveStream.canSkipPrevious)
    }

    @Test func `treats skip and seek style commands as next and previous`() {
        #expect(PlayCaps.fastForward.canSkipNext)
        #expect(PlayCaps.skipForward.canSkipNext)
        #expect(PlayCaps.rewind.canSkipPrevious)
        #expect(PlayCaps.skipBackward.canSkipPrevious)
    }

    @Test func `main button stops streams that cannot pause`() {
        #expect(PrimaryPlaybackAction(status: .playing, caps: liveStream) == .stop)
    }

    @Test func `main button pauses when supported`() {
        #expect(PrimaryPlaybackAction(status: .playing, caps: [.pause, .stop]) == .pause)
    }

    @Test(arguments: [PlayStatus.stopped, .paused])
    func `main button plays when not playing`(status: PlayStatus) {
        #expect(PrimaryPlaybackAction(status: status, caps: liveStream) == .play)
    }

    @Test func `main button has no action without pause or stop`() {
        #expect(PrimaryPlaybackAction(status: .playing, caps: []) == nil)
    }

    @Test func `treats rebuffering as buffering`() {
        #expect(PlayStatus(fsapiValue: "4") == .buffering)
    }
}

struct PresetSlotTests {
    @Test func `keeps saved presets with their original slot numbers`() {
        let slots = [
            FSAPIListParser.Item(key: 0, fields: ["name": "BBC Radio 4"]),
            FSAPIListParser.Item(key: 1, fields: ["name": ""]),
            FSAPIListParser.Item(key: 2, fields: [:]),
            FSAPIListParser.Item(key: 3, fields: ["name": "Jazz FM"]),
        ]
        #expect(RadioPreset.saved(in: slots) == [
            RadioPreset(id: 0, name: "BBC Radio 4"),
            RadioPreset(id: 3, name: "Jazz FM"),
        ])
    }
}

struct ListPagingTests {
    @Test func `detects the end of a list`() {
        let xml = """
        <fsapiResponse>
        <status>FS_OK</status>
        <item key="9"><field name="label"><c8_array>Aux In</c8_array></field></item>
        <listend/>
        </fsapiResponse>
        """
        #expect(FSAPIListParser.parse(Data(xml.utf8)).reachedEnd)
    }

    @Test func `detects a partial page`() {
        let xml = """
        <fsapiResponse>
        <status>FS_OK</status>
        <item key="4"><field name="name"><c8_array>BBC World Service</c8_array></field></item>
        </fsapiResponse>
        """
        #expect(!FSAPIListParser.parse(Data(xml.utf8)).reachedEnd)
    }

    @Test func `recognises loading placeholders`() {
        let xml = """
        <fsapiResponse>
        <status>FS_OK</status>
        <item key="0"><field name="name"><c8_array></c8_array></field><field name="type"><u8>255</u8></field></item>
        <item key="1"><field name="name"><c8_array>Stations</c8_array></field><field name="type"><u8>0</u8></field></item>
        <listend/>
        </fsapiResponse>
        """
        let items = FSAPIListParser.parse(Data(xml.utf8)).items
        #expect(items.map(\.isLoadingPlaceholder) == [true, false])
    }
}
