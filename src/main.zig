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
}; // MtPoint defined

// External Dependencies for CGEvent
extern "c" fn CGEventSourceCreate(state: c_int) ?c.CGEventSourceRef;
// extern "c" fn CGEventCreate(source: ?c.CGEventSourceRef) c.CGEventRef; // Already in ApplicationServices? Likely yes via C import.

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
const MTContactCallbackFunction = *const fn (MTDeviceRef, [*c]Touch, c_int, f64, c_int) callconv(.c) c_int;

// External functions from MultitouchSupport.framework
extern "c" fn MTDeviceCreateList() callconv(.c) c.CFMutableArrayRef;
extern "c" fn MTRegisterContactFrameCallback(device: MTDeviceRef, callback: MTContactCallbackFunction) callconv(.c) void;
extern "c" fn MTDeviceStart(device: MTDeviceRef, state: c_int) callconv(.c) void;
extern "c" fn MTDeviceIsBuiltIn(device: MTDeviceRef) callconv(.c) bool;
extern "c" fn MTDeviceGetFamilyID(device: MTDeviceRef) callconv(.c) c_int;

// Tap Detection State
const TapState = struct {
    start_time: f64,
    start_pos: MtPoint,
    possible: bool,
};

var tap_state: TapState = .{
    .start_time = 0,
    .start_pos = .{ .x = 0, .y = 0 },
    .possible = false,
};

fn clickAtCursor() void {
    const event_source = c.CGEventSourceCreate(c.kCGEventSourceStateHIDSystemState);
    const pos = c.CGEventGetLocation(c.CGEventCreate(event_source));
    c.CFRelease(event_source);

    const down = c.CGEventCreateMouseEvent(null, c.kCGEventLeftMouseDown, pos, c.kCGMouseButtonLeft);
    const up = c.CGEventCreateMouseEvent(null, c.kCGEventLeftMouseUp, pos, c.kCGMouseButtonLeft);

    c.CGEventPost(c.kCGHIDEventTap, down);
    c.CGEventPost(c.kCGHIDEventTap, up);

    c.CFRelease(down);
    c.CFRelease(up);
    std.debug.print("Click simulated at ({d}, {d})\n", .{ pos.x, pos.y });
}

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
export fn touchCallback(device: MTDeviceRef, data: [*c]Touch, n_fingers: c_int, timestamp: f64, frame: c_int) c_int {
    _ = frame;

    // Magic Mouse Detection (Not Built-in)
    const is_magic_mouse = !MTDeviceIsBuiltIn(device);

    if (n_fingers >= 2) {
        // Reset tap state if multiple fingers
        tap_state.possible = false;

        // ... Pinch logic (existing) ...
        const f1 = &data[0];
        const f2 = &data[1];
        const dx = f1.normalized.position.x - f2.normalized.position.x;
        const dy = f1.normalized.position.y - f2.normalized.position.y;
        const dist_ab = @sqrt(dx * dx + dy * dy);

        if (dist_ab > 0.40 and dist_ab < 0.41) {
            std.debug.print("pinch-in detected\n", .{});
        } else if (dist_ab < 0.80 and dist_ab > 0.79) {
            std.debug.print("pinch-out detected\n", .{});
        }
    } else if (n_fingers == 1 and is_magic_mouse) {
        const f = &data[0];
        // 1 Finger: Start or Continue Tap
        if (!tap_state.possible) {
            // New potential tap
            tap_state.possible = true;
            tap_state.start_time = timestamp;
            tap_state.start_pos = f.normalized.position;
        } else {
            // Check movement threshold
            const dx = f.normalized.position.x - tap_state.start_pos.x;
            const dy = f.normalized.position.y - tap_state.start_pos.y;
            const dist_sq = dx * dx + dy * dy;
            if (dist_sq > 0.002) { // Sensitivity threshold
                tap_state.possible = false;
            }
        }
    } else if (n_fingers == 0) {
        // 0 Fingers: Lift
        if (tap_state.possible) {
            const duration = timestamp - tap_state.start_time;
            if (duration < 0.3) { // 300ms max duration for tap
                std.debug.print("Tap detected! Duration: {d:.3}s\n", .{duration});
                clickAtCursor();
            }
            tap_state.possible = false;
        }
    } else {
        tap_state.possible = false;
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
