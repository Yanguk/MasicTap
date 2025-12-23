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
const MTContactCallbackFunction = *const fn (MTDeviceRef, [*c]Touch, c_int, f64, c_int) callconv(.c) c_int;

// External functions from MultitouchSupport.framework
extern "c" fn MTDeviceCreateList() callconv(.c) c.CFMutableArrayRef;
extern "c" fn MTRegisterContactFrameCallback(device: MTDeviceRef, callback: MTContactCallbackFunction) callconv(.c) void;
extern "c" fn MTDeviceStart(device: MTDeviceRef, state: c_int) callconv(.c) void;
extern "c" fn MTDeviceIsBuiltIn(device: MTDeviceRef) callconv(.c) bool;
extern "c" fn MTDeviceGetFamilyID(device: MTDeviceRef) callconv(.c) c_int;

// External Dependencies for CGEvent
extern "c" fn CGEventSourceCreate(state: c_int) ?c.CGEventSourceRef;

// 각 손가락별 탭 상태 추적
const FingerTapState = struct {
    identifier: c_int,
    start_time: f64,
    start_pos: MtPoint,
    tracking: bool,
};

const MAX_FINGERS = 10;
var finger_states: [MAX_FINGERS]FingerTapState = undefined;
var initialized = false;

fn initFingerStates() void {
    if (!initialized) {
        for (&finger_states) |*state| {
            state.* = .{
                .identifier = -1,
                .start_time = 0,
                .start_pos = .{ .x = 0, .y = 0 },
                .tracking = false,
            };
        }
        initialized = true;
    }
}

fn findFingerState(identifier: c_int) ?*FingerTapState {
    for (&finger_states) |*state| {
        if (state.tracking and state.identifier == identifier) {
            return state;
        }
    }
    return null;
}

fn getAvailableFingerState() ?*FingerTapState {
    for (&finger_states) |*state| {
        if (!state.tracking) {
            return state;
        }
    }
    return null;
}

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
    std.debug.print("✓ Click simulated at ({d}, {d})\n", .{ pos.x, pos.y });
}

// 터치 콜백 함수
export fn touchCallback(device: MTDeviceRef, data: [*c]Touch, n_fingers: c_int, timestamp: f64, frame: c_int) c_int {
    _ = frame;

    initFingerStates();

    // Magic Mouse Detection (Not Built-in)
    // const is_magic_mouse = !MTDeviceIsBuiltIn(device);
    const device_ptr = @intFromPtr(device);

    // // Magic Mouse가 아니면 무시
    // if (!is_magic_mouse) {
    //     return 0;
    // }

    // 현재 프레임에 있는 손가락 ID 목록
    var current_ids: [MAX_FINGERS]c_int = undefined;
    var i: usize = 0;
    while (i < @as(usize, @intCast(n_fingers))) : (i += 1) {
        current_ids[i] = data[i].identifier;
    }

    // 각 손가락 처리
    i = 0;
    while (i < @as(usize, @intCast(n_fingers))) : (i += 1) {
        const f = &data[i];

        if (findFingerState(f.identifier)) |state| {
            // 이미 추적 중인 손가락 - 이동 체크
            const dx = f.normalized.position.x - state.start_pos.x;
            const dy = f.normalized.position.y - state.start_pos.y;
            const dist_sq = dx * dx + dy * dy;

            if (dist_sq > 0.002) {
                // 너무 많이 움직임 - 추적 중단
                state.tracking = false;
            }
        } else {
            // 새로운 손가락 - 추적 시작
            if (getAvailableFingerState()) |state| {
                state.* = .{
                    .identifier = f.identifier,
                    .start_time = timestamp,
                    .start_pos = f.normalized.position,
                    .tracking = true,
                };
                std.debug.print("[0x{X}] Finger {} tap started at ({d:.4}, {d:.4})\n", .{ device_ptr, f.identifier, f.normalized.position.x, f.normalized.position.y });
            }
        }
    }

    // 떼어진 손가락 감지 및 탭 판정
    for (&finger_states) |*state| {
        if (!state.tracking) continue;

        // 현재 프레임에 이 손가락이 없으면 떼어진 것
        var found = false;
        var j: usize = 0;
        while (j < @as(usize, @intCast(n_fingers))) : (j += 1) {
            if (current_ids[j] == state.identifier) {
                found = true;
                break;
            }
        }

        if (!found) {
            // 손가락이 떼어짐
            const duration = timestamp - state.start_time;

            // 최소 터치 시간과 최대 터치 시간 체크
            if (duration > 0.05 and duration < 0.5) {
                // 탭 성공!
                std.debug.print("[0x{X}] ✓ Tap detected! Finger {}, Duration: {d:.3}s\n", .{ device_ptr, state.identifier, duration });
                clickAtCursor();
            } else if (duration <= 0.05) {
                std.debug.print("[0x{X}] Tap too short for finger {} ({d:.3}s)\n", .{ device_ptr, state.identifier, duration });
            } else {
                std.debug.print("[0x{X}] Tap too long for finger {} ({d:.3}s)\n", .{ device_ptr, state.identifier, duration });
            }

            state.tracking = false;
        }

    }

    return 0;
}

pub fn main() !void {
    std.debug.print("Starting multitouch detection...\n", .{});

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
