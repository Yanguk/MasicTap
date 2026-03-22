const std = @import("std");
const tap = @import("zig_my_mouse");

const c = @cImport({
    @cInclude("unistd.h");
    @cInclude("math.h");
    @cInclude("CoreFoundation/CoreFoundation.h");
    @cInclude("ApplicationServices/ApplicationServices.h");
});

// ----------------- 타입 정의 (C 바인딩) -----------------
const MtPoint = extern struct { x: f32, y: f32 };
const MtReadout = extern struct { position: MtPoint, velocity: MtPoint };
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

const MTDeviceRef = *anyopaque;
const MTContactCallbackFunction = *const fn (MTDeviceRef, [*c]Touch, c_int, f64, c_int) callconv(.c) c_int;

extern fn MTDeviceCreateList() c.CFArrayRef;
extern fn MTRegisterContactFrameCallback(device: MTDeviceRef, callback: MTContactCallbackFunction) void;
extern fn MTDeviceStart(device: MTDeviceRef, options: c_int) void;
extern fn MTDeviceIsBuiltIn(device: MTDeviceRef) bool;

// ----------------- 전역 상태 -----------------
var finger_table = tap.FingerStateTable.init();
var current_ids: [tap.MAX_FINGERS]c_int = undefined;
var prev_n: usize = 0;

// ----------------- 마우스 클릭 -----------------
fn clickAtCursor() void {
    const source = c.CGEventSourceCreate(c.kCGEventSourceStateHIDSystemState);
    const event = c.CGEventCreate(source);
    const pos = c.CGEventGetLocation(event);
    c.CFRelease(event);
    c.CFRelease(source);

    const down = c.CGEventCreateMouseEvent(null, c.kCGEventLeftMouseDown, pos, c.kCGMouseButtonLeft);
    const up = c.CGEventCreateMouseEvent(null, c.kCGEventLeftMouseUp, pos, c.kCGMouseButtonLeft);

    c.CGEventPost(c.kCGHIDEventTap, down);
    c.CGEventPost(c.kCGHIDEventTap, up);

    c.CFRelease(down);
    c.CFRelease(up);

    std.debug.print("✓ Click at ({d}, {d})\n", .{ pos.x, pos.y });
}

// ----------------- 탭 감지 콜백 -----------------
export fn touchCallback(device: MTDeviceRef, data: [*c]Touch, n_fingers: c_int, timestamp: f64, frame: c_int) c_int {
    _ = frame;

    const n: usize = @intCast(n_fingers);

    // 현재 터치 id 저장
    for (0..n) |i| {
        current_ids[i] = data[i].identifier;
    }

    for (0..n) |i| {
        const t = data[i];
        const id: i32 = @intCast(t.identifier);

        if (finger_table.find(id)) |state| {
            // 기존 추적 손가락: 이동량 초과 시 취소
            const dx = t.normalized.position.x - state.start_pos.x;
            const dy = t.normalized.position.y - state.start_pos.y;
            if (tap.isTapMoveCancelled(dx, dy)) {
                state.tracking = false;
            }
        } else if (n > prev_n) {
            // 손가락 수가 증가했을 때만 새 손가락 추적 시작
            if (finger_table.getAvailable()) |state| {
                state.* = .{
                    .identifier = id,
                    .start_time = timestamp,
                    .start_pos = .{ .x = t.normalized.position.x, .y = t.normalized.position.y },
                    .tracking = true,
                };
                std.debug.print("[0x{X}] Finger {} tap started at ({d:.4}, {d:.4})\n",
                    .{ @intFromPtr(device), id, t.normalized.position.x, t.normalized.position.y });
            }
        }
    }

    // 손가락 떼기 확인
    for (&finger_table.states) |*s| {
        if (!s.tracking) continue;

        var still_down = false;
        for (0..n) |i| {
            if (current_ids[i] == s.identifier) {
                still_down = true;
                break;
            }
        }

        if (!still_down) {
            const duration = timestamp - s.start_time;
            if (tap.isTapDurationValid(duration)) {
                std.debug.print("[0x{X}] ✓ Tap! Finger {} duration: {d:.3}s\n",
                    .{ @intFromPtr(device), s.identifier, duration });
                clickAtCursor();
            }
            s.tracking = false;
        }
    }

    prev_n = n;
    return 0;
}

// ----------------- 메인 -----------------
pub fn main() void {
    std.debug.print("Starting multitouch detection...\n", .{});

    const devices = MTDeviceCreateList();
    if (devices == null) { std.debug.print("No devices\n", .{}); return; }

    const count = c.CFArrayGetCount(devices);
    std.debug.print("Found {} device(s)\n", .{count});

    const device_count: usize = @intCast(count);
    for (0..device_count) |idx| {
        const cf_idx: c.CFIndex = @intCast(idx);
        const raw_dev = c.CFArrayGetValueAtIndex(devices, cf_idx);
        if (raw_dev == null) continue;
        const dev: MTDeviceRef = @ptrCast(@constCast(raw_dev));

        if (MTDeviceIsBuiltIn(dev)) {
            std.debug.print("Skipping built-in device\n", .{});
            continue;
        }

        std.debug.print("External device detected, registering...\n", .{});
        MTRegisterContactFrameCallback(dev, touchCallback);
        MTDeviceStart(dev, 0);
    }

    std.debug.print("Press Ctrl-C to abort\n", .{});
    _ = c.sleep(std.math.maxInt(c_uint));
}
