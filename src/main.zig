const std = @import("std");
const c = @cImport({
    @cInclude("unistd.h");
    @cInclude("math.h");
    @cInclude("CoreFoundation/CoreFoundation.h");
    @cInclude("ApplicationServices/ApplicationServices.h");
});

// MultiTouch 구조체 정의
const MtPoint = extern struct {
    x: f32,
    y: f32,
};

const MtReadout = extern struct {
    position: MtPoint,
    velocity: MtPoint,
};

const Touch = extern struct {
    frame: c_int,
    timestamp: f64,
    identifier: c_int,
    state: c_int,
    unknown1: c_int,
    unknown2: c_int,
    normalized: MtReadout,
    size: f32,
    unknown3: c_int,
    angle: f32,
    major_axis: f32,
    minor_axis: f32,
    unknown4: MtReadout,
    unknown5: [2]c_int,
    unknown6: f32,
};

// MultitouchSupport.framework 타입 정의
const MTDeviceRef = *anyopaque;
const MTContactCallbackFunction = *const fn (c_int, [*c]Touch, c_int, f64, c_int) callconv(.c) c_int;

// External functions from MultitouchSupport.framework
extern "c" fn MTDeviceCreateList() callconv(.c) c.CFMutableArrayRef;
extern "c" fn MTRegisterContactFrameCallback(device: MTDeviceRef, callback: MTContactCallbackFunction) callconv(.c) void;
extern "c" fn MTDeviceStart(device: MTDeviceRef, state: c_int) callconv(.c) void;

// 디버그 정보 출력
fn printDebugInfos(n_fingers: c_int, data: [*c]Touch) void {
    var i: usize = 0;
    while (i < @as(usize, @intCast(n_fingers))) : (i += 1) {
        const f = &data[i];
        std.debug.print(
            "Finger: {}, frame: {}, timestamp: {d:.6}, ID: {}, state: {}, " ++
                "PosX: {d:.4}, PosY: {d:.4}, VelX: {d:.4}, VelY: {d:.4}, " ++
                "Angle: {d:.4}, MajorAxis: {d:.4}, MinorAxis: {d:.4}\n",
            .{
                i,
                f.frame,
                f.timestamp,
                f.identifier,
                f.state,
                f.normalized.position.x,
                f.normalized.position.y,
                f.normalized.velocity.x,
                f.normalized.velocity.y,
                f.angle,
                f.major_axis,
                f.minor_axis,
            },
        );
    }
}

// 터치 콜백 함수
export fn touchCallback(device: c_int, data: [*c]Touch, n_fingers: c_int, timestamp: f64, frame: c_int) c_int {
    _ = device;
    _ = timestamp;
    _ = frame;

    // 2개 이상의 손가락이 감지될 때만 처리
    if (n_fingers >= 2) {
        // 디버그 정보 출력 (필요시 주석 해제)
        // printDebugInfos(n_fingers, data);

        const f1 = &data[0]; // 첫 번째 손가락
        const f2 = &data[1]; // 두 번째 손가락

        // 두 손가락 사이의 유클리드 거리 계산
        const dx = f1.normalized.position.x - f2.normalized.position.x;
        const dy = f1.normalized.position.y - f2.normalized.position.y;
        const dist_ab = @sqrt(dx * dx + dy * dy);

        // Pinch-in (확대) 감지
        if (dist_ab > 0.40 and dist_ab < 0.41) {
            std.debug.print("pinch-in detected\n", .{});

            // Command + "+" 키 입력 (확대)
            _ = c.CGPostKeyboardEvent(0, 55, 1); // Command 누름
            _ = c.CGPostKeyboardEvent(0, 69, 1); // "+" 누름
            _ = c.CGPostKeyboardEvent(0, 69, 0); // "+" 뗌
            _ = c.CGPostKeyboardEvent(0, 55, 0); // Command 뗌
        }
        // Pinch-out (축소) 감지
        else if (dist_ab < 0.80 and dist_ab > 0.79) {
            std.debug.print("pinch-out detected\n", .{});

            // Command + "-" 키 입력 (축소)
            _ = c.CGPostKeyboardEvent(0, 55, 1); // Command 누름
            _ = c.CGPostKeyboardEvent(0, 78, 1); // "-" 누름
            _ = c.CGPostKeyboardEvent(0, 78, 0); // "-" 뗌
            _ = c.CGPostKeyboardEvent(0, 55, 0); // Command 뗌
        }
    }

    return 0;
}

pub fn main() !void {
    std.debug.print("Starting multitouch detection...\n", .{});

    // 프레임워크 동적 로드 (Removed for static linking)
    // try loadMultitouchFramework();

    // 멀티터치 디바이스 리스트 가져오기
    const device_list = MTDeviceCreateList();
    if (device_list == null) {
        std.debug.print("Failed to get device list\n", .{});
        return error.NoDevices;
    }

    // 디바이스 개수 확인
    const count = c.CFArrayGetCount(device_list);
    std.debug.print("Found {} multitouch device(s)\n", .{count});

    if (count == 0) {
        std.debug.print("No multitouch devices found\n", .{});
        return;
    }

    // 각 디바이스에 콜백 등록 및 시작
    var i: c.CFIndex = 0;
    while (i < count) : (i += 1) {
        const device: MTDeviceRef = @ptrCast(@constCast(c.CFArrayGetValueAtIndex(device_list, i)));

        // 콜백 등록
        MTRegisterContactFrameCallback(device, touchCallback);

        // 이벤트 전송 시작
        MTDeviceStart(device, 0);

        std.debug.print("Started device {}\n", .{i});
    }

    std.debug.print("Press Ctrl-C to abort\n", .{});

    // 무한 대기
    _ = c.sleep(std.math.maxInt(c_uint));
}
