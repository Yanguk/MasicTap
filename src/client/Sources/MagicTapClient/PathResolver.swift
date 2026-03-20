import Foundation

/// 실행 파일 경로로부터 백엔드 바이너리 경로를 탐색합니다.
/// - Parameters:
///   - executablePath: `ProcessInfo.processInfo.arguments[0]`
///   - fileExists: 파일 존재 여부 확인 함수 (테스트에서 주입 가능)
/// - Returns: 발견된 경로, 없으면 fallback 상대 경로
func resolveBackendPath(
    executablePath: String,
    fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
) -> String {
    // 1) 앱 번들 내부 (배포 시)
    if let bundled = Bundle.main.path(forAuxiliaryExecutable: "zig_my_mouse") {
        return bundled
    }

    // 2) 실행 파일(.build/arch/config/MagicTapClient) 기준으로 프로젝트 루트 탐색
    //    경로 구조: <root>/src/client/.build/<arch>/<config>/MagicTapClient
    //    → deletingLastPathComponent 6번 → <root>
    var dir = (executablePath as NSString).deletingLastPathComponent  // <config>/
    for _ in 0..<5 {
        dir = (dir as NSString).deletingLastPathComponent
    }
    // dir == <project-root>
    let candidate = dir + "/src/backend/zig-out/bin/zig_my_mouse"
    if fileExists(candidate) { return candidate }

    // 3) fallback
    return "../../src/backend/zig-out/bin/zig_my_mouse"
}
