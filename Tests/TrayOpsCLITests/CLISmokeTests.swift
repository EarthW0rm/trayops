import Testing
import Foundation
import TrayOpsTestSupport

@Suite("CLI smoke")
struct CLISmokeTests {
    @Test("trayops --help exits 0 and prints the command name")
    func helpExitsZero() throws {
        let process = Process()
        process.executableURL = TestBinary.trayops
        process.arguments = ["--help"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("trayops"))
    }
}
