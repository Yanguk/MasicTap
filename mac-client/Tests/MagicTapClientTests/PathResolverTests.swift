import XCTest
@testable import MagicTapClient

final class PathResolverTests: XCTestCase {

    // swift run 빌드 결과물의 실제 경로 구조를 시뮬레이션
    private let fakeExe = "/project/magic-tap/mac-client/.build/arm64-apple-macosx/debug/MagicTapClient"
    private let expectedCandidate = "/project/magic-tap/zig-out/bin/zig_my_mouse"

    func test_resolves_project_root_from_swift_run_path() {
        let result = resolveBackendPath(
            executablePath: fakeExe,
            fileExists: { $0 == self.expectedCandidate }
        )
        XCTAssertEqual(result, expectedCandidate)
    }

    func test_resolves_release_build_path() {
        let releaseExe = "/project/magic-tap/mac-client/.build/arm64-apple-macosx/release/MagicTapClient"
        let expected = "/project/magic-tap/zig-out/bin/zig_my_mouse"
        let result = resolveBackendPath(
            executablePath: releaseExe,
            fileExists: { $0 == expected }
        )
        XCTAssertEqual(result, expected)
    }

    func test_falls_back_when_candidate_not_found() {
        let result = resolveBackendPath(
            executablePath: fakeExe,
            fileExists: { _ in false }  // 아무것도 없음
        )
        XCTAssertEqual(result, "../zig-out/bin/zig_my_mouse")
    }

    func test_path_segments_count() {
        // 경로 분해: exe → debug → arm64-... → .build → mac-client → project-root
        let exe = "/a/b/mac-client/.build/arch/debug/Binary"
        let result = resolveBackendPath(
            executablePath: exe,
            fileExists: { _ in true }
        )
        XCTAssertEqual(result, "/a/b/zig-out/bin/zig_my_mouse")
    }

    func test_actual_binary_exists_in_repo() throws {
        // 실제 레포에서 바이너리가 존재하는지 통합 검증
        let actualExe = "/Users/yangukheo/Desktop/1_private/magic-tap/mac-client/.build/arm64-apple-macosx/debug/MagicTapClient"
        guard FileManager.default.fileExists(atPath: actualExe) else {
            throw XCTSkip("빌드된 실행 파일 없음 — swift build 먼저 실행하세요")
        }
        let result = resolveBackendPath(executablePath: actualExe)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: result),
            "탐색된 경로가 실제로 존재해야 합니다: \(result)"
        )
        XCTAssertTrue(result.hasSuffix("zig-out/bin/zig_my_mouse"))
    }
}
