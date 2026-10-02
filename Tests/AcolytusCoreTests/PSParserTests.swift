@testable import AcolytusCore
import XCTest

final class PSParserTests: XCTestCase {
    let stats = """
      101     1   501  812340 S      2-03:04:05 /opt/homebrew/bin/node
      102   900   501  204800 S        12:30 /Users/cris/.nvm/versions/node/v20.11.0/bin/node
      103   900   501  102400 T        01:02 /usr/local/bin/node
      104     1   501   51200 S        05:00 /Applications/Visual Studio Code.app/Contents/MacOS/Electron
      105     1     0  409600 S        05:00 /opt/homebrew/bin/node
      106   900   501       0 Z        00:10 /opt/homebrew/bin/node
    """
    let args = """
      101 node /Users/cris/dev/limonada/node_modules/.bin/next dev
      102 node /Users/cris/dev/acme/node_modules/typescript/lib/tsserver.js --serverMode partialSemantic
      103 node server.js
      104 /Applications/Visual Studio Code.app/Contents/MacOS/Electron
      105 node /usr/local/lib/some-root-daemon.js
      106 <defunct>
    """

    func testFiltersNodeProcessesOfCurrentUser() {
        let processes = PSParser.nodeProcesses(statsOutput: stats, argsOutput: args, uid: 501, excluding: 999)
        XCTAssertEqual(processes.map(\.pid), [101, 102, 103, 106])

        let next = processes[0]
        XCTAssertTrue(next.isOrphan)
        XCTAssertTrue(next.isReapCandidate)
        XCTAssertEqual(next.elapsedSeconds, 2 * 86_400 + 3 * 3_600 + 4 * 60 + 5)
        XCTAssertEqual(next.projectHint, "limonada")
        XCTAssertEqual(next.shortCommand, "next dev")

        let tsserver = processes[1]
        XCTAssertFalse(tsserver.isReapCandidate)
        XCTAssertEqual(tsserver.projectHint, "acme")
        XCTAssertEqual(tsserver.shortCommand, "tsserver.js --serverMode partialSemantic")

        XCTAssertTrue(processes[2].isStopped)
        XCTAssertTrue(processes[2].isReapCandidate)

        XCTAssertTrue(processes[3].isZombie)
        XCTAssertFalse(processes[3].isReapCandidate)
    }

    func testRenamedProcessIsStillNode() {
        XCTAssertTrue(PSParser.isNode(executable: "/opt/homebrew/bin/node", command: "next-server (v14.2.3)"))
        XCTAssertFalse(PSParser.isNode(executable: "/usr/bin/nodemon-like", command: "nodemon-like"))
    }

    func testElapsed() {
        XCTAssertEqual(PSParser.parseElapsed("00:07"), 7)
        XCTAssertEqual(PSParser.parseElapsed("01:00:00"), 3_600)
        XCTAssertEqual(PSParser.parseElapsed("1-00:00:00"), 86_400)
        XCTAssertNil(PSParser.parseElapsed("abc"))
    }
}
