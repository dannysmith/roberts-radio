import Foundation
@testable import RadioBar
import Testing

struct DeviceDescriptionTests {
    @Test func `accepts FSAPI device`() {
        let xml = """
        <netRemote>
        <friendlyName>frname</friendlyName>
        <version>ir-cui-FS2340-0000-0618_V4.6.18.64a342.EX5_14-1B10</version>
        <webfsapi>http://192.168.1.72:80/fsapi</webfsapi>
        </netRemote>
        """
        #expect(FSAPIDeviceParser.fsapiURL(from: Data(xml.utf8))?.absoluteString == "http://192.168.1.72:80/fsapi")
    }

    @Test(arguments: [
        "<html><head><title>404 Not Found</title></head><body><h1>Not Found</h1></body></html>",
        "<root><device><friendlyName>Hue Bridge</friendlyName></device></root>",
        "<netRemote><webfsapi>http://192.168.1.72/other</webfsapi></netRemote>",
        "<netRemote><webfsapi>ftp://192.168.1.72/fsapi</webfsapi></netRemote>",
        "<other><webfsapi>http://192.168.1.72/fsapi</webfsapi></other>",
        "not xml",
    ])
    func `rejects other responses`(response: String) {
        #expect(FSAPIDeviceParser.fsapiURL(from: Data(response.utf8)) == nil)
    }
}

struct SSDPReplyTests {
    @Test func `recognises radio reply`() {
        let reply = [
            "HTTP/1.1 200 OK",
            "CACHE-CONTROL: max-age=1800",
            "EXT: ",
            "LOCATION: http://192.168.1.72:80/device",
            "SERVER: FOS/1.0 UPnP/1.0 Jupiter/6.5",
            "ST: urn:schemas-frontier-silicon-com:undok:fsapi:1",
            "SPEAKER-NAME: iStream3L",
            "",
            "",
        ].joined(separator: "\r\n")
        #expect(SSDPSearch.isRadioReply(reply))
    }

    @Test func `ignores other devices`() {
        let reply = [
            "HTTP/1.1 200 OK",
            "LOCATION: http://192.168.1.178:80/description.xml",
            "SERVER: Hue/1.0 UPnP/1.0 IpBridge/1.78.0",
            "ST: upnp:rootdevice",
            "",
            "",
        ].joined(separator: "\r\n")
        #expect(!SSDPSearch.isRadioReply(reply))
    }

    @Test func `ignores search requests`() {
        let search = [
            "M-SEARCH * HTTP/1.1",
            "HOST: 239.255.255.250:1900",
            "ST: urn:schemas-frontier-silicon-com:undok:fsapi:1",
            "",
            "",
        ].joined(separator: "\r\n")
        #expect(!SSDPSearch.isRadioReply(search))
    }
}

struct LocalNetworkTests {
    private let address: UInt32 = 0xC0A8_0188 // 192.168.1.136

    @Test func `lists other hosts on subnet`() {
        let hosts = LocalNetwork(address: address, netmask: 0xFFFF_FF00).hosts
        #expect(hosts.count == 253)
        #expect(hosts.first == "192.168.1.1")
        #expect(hosts.last == "192.168.1.254")
        #expect(!hosts.contains("192.168.1.136"))
    }

    @Test func `limits large subnets to surrounding 24`() {
        let hosts = LocalNetwork(address: address, netmask: 0xFFFF_0000).hosts
        #expect(hosts.count == 253)
        #expect(hosts.allSatisfy { $0.hasPrefix("192.168.1.") })
    }

    @Test func `handles single host network`() {
        #expect(LocalNetwork(address: address, netmask: 0xFFFF_FFFF).hosts.isEmpty)
    }
}
