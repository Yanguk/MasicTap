const std = @import("std");

// ----------------- 탭 조건 상수 -----------------
pub const TAP_MIN_DURATION: f64 = 0.05;
pub const TAP_MAX_DURATION: f64 = 0.5;
pub const TAP_MAX_MOVE: f32 = 0.045;
pub const MAX_FINGERS: usize = 10;
pub const DOUBLE_TAP_MAX_INTERVAL: f64 = 0.30;

// ----------------- 타입 -----------------
pub const MtPoint = struct { x: f32, y: f32 };

pub const FingerTapState = struct {
    identifier: i32,
    start_time: f64,
    start_pos: MtPoint,
    tracking: bool,
};

// ----------------- 순수 판정 함수 -----------------

/// 탭 지속 시간이 유효한 범위인지 확인
pub fn isTapDurationValid(duration: f64) bool {
    return duration >= TAP_MIN_DURATION and duration <= TAP_MAX_DURATION;
}

/// 손가락 이동량이 취소 임계값을 초과했는지 확인 (정규화 좌표)
pub fn isTapMoveCancelled(dx: f32, dy: f32) bool {
    return dx * dx + dy * dy > TAP_MAX_MOVE * TAP_MAX_MOVE;
}

// ----------------- 손가락 상태 테이블 -----------------
pub const FingerStateTable = struct {
    states: [MAX_FINGERS]FingerTapState,

    pub fn init() FingerStateTable {
        var t: FingerStateTable = undefined;
        for (&t.states) |*s| {
            s.* = .{
                .identifier = -1,
                .start_time = 0,
                .start_pos = .{ .x = 0, .y = 0 },
                .tracking = false,
            };
        }
        return t;
    }

    /// identifier가 일치하는 추적 중인 손가락 반환
    pub fn find(self: *FingerStateTable, id: i32) ?*FingerTapState {
        for (&self.states) |*s| {
            if (s.tracking and s.identifier == id) return s;
        }
        return null;
    }

    /// 비어있는 슬롯 반환
    pub fn getAvailable(self: *FingerStateTable) ?*FingerTapState {
        for (&self.states) |*s| {
            if (!s.tracking) return s;
        }
        return null;
    }

    /// 추적 중인 손가락 수
    pub fn trackingCount(self: *const FingerStateTable) usize {
        var count: usize = 0;
        for (self.states) |s| {
            if (s.tracking) count += 1;
        }
        return count;
    }
};

// ===================== 테스트 =====================

test "isTapDurationValid - 너무 짧음" {
    try std.testing.expect(!isTapDurationValid(0.0));
    try std.testing.expect(!isTapDurationValid(0.01));
    try std.testing.expect(!isTapDurationValid(TAP_MIN_DURATION - 0.001));
}

test "isTapDurationValid - 유효 범위" {
    try std.testing.expect(isTapDurationValid(TAP_MIN_DURATION));
    try std.testing.expect(isTapDurationValid(0.1));
    try std.testing.expect(isTapDurationValid(0.3));
    try std.testing.expect(isTapDurationValid(TAP_MAX_DURATION));
}

test "isTapDurationValid - 너무 김" {
    try std.testing.expect(!isTapDurationValid(TAP_MAX_DURATION + 0.001));
    try std.testing.expect(!isTapDurationValid(1.0));
}

test "isTapMoveCancelled - 임계값 이내" {
    try std.testing.expect(!isTapMoveCancelled(0.0, 0.0));
    try std.testing.expect(!isTapMoveCancelled(0.01, 0.01));
    // 대각선 이동: sqrt(0.03^2 + 0.03^2) ≈ 0.042 < 0.045
    try std.testing.expect(!isTapMoveCancelled(0.03, 0.03));
}

test "isTapMoveCancelled - 임계값 초과" {
    try std.testing.expect(isTapMoveCancelled(TAP_MAX_MOVE + 0.001, 0.0));
    try std.testing.expect(isTapMoveCancelled(0.0, TAP_MAX_MOVE + 0.001));
    // 대각선: sqrt(0.04^2 + 0.04^2) ≈ 0.057 > 0.045
    try std.testing.expect(isTapMoveCancelled(0.04, 0.04));
}

test "FingerStateTable.init - 모든 슬롯 비어있음" {
    const table = FingerStateTable.init();
    for (table.states) |s| {
        try std.testing.expect(!s.tracking);
        try std.testing.expectEqual(@as(i32, -1), s.identifier);
    }
}

test "FingerStateTable.find - 빈 테이블에서 null 반환" {
    var table = FingerStateTable.init();
    try std.testing.expectEqual(@as(?*FingerTapState, null), table.find(1));
    try std.testing.expectEqual(@as(?*FingerTapState, null), table.find(0));
}

test "FingerStateTable.find - 추적 중인 손가락 탐색" {
    var table = FingerStateTable.init();
    const slot = table.getAvailable().?;
    slot.* = .{
        .identifier = 42,
        .start_time = 1.0,
        .start_pos = .{ .x = 0.5, .y = 0.5 },
        .tracking = true,
    };

    try std.testing.expectEqual(slot, table.find(42));
    try std.testing.expectEqual(@as(?*FingerTapState, null), table.find(99));
}

test "FingerStateTable.find - 추적 중지된 손가락은 반환하지 않음" {
    var table = FingerStateTable.init();
    table.states[0] = .{
        .identifier = 7,
        .start_time = 0.5,
        .start_pos = .{ .x = 0.1, .y = 0.2 },
        .tracking = false, // 추적 중지
    };

    try std.testing.expectEqual(@as(?*FingerTapState, null), table.find(7));
}

test "FingerStateTable.getAvailable - 슬롯이 꽉 찬 경우 null 반환" {
    var table = FingerStateTable.init();
    for (&table.states) |*s| {
        s.tracking = true;
        s.identifier = 0;
    }
    try std.testing.expectEqual(@as(?*FingerTapState, null), table.getAvailable());
}

test "FingerStateTable.trackingCount" {
    var table = FingerStateTable.init();
    try std.testing.expectEqual(@as(usize, 0), table.trackingCount());

    table.states[0].tracking = true;
    table.states[3].tracking = true;
    try std.testing.expectEqual(@as(usize, 2), table.trackingCount());
}

test "FingerStateTable - 여러 손가락 동시 추적" {
    var table = FingerStateTable.init();

    const s1 = table.getAvailable().?;
    s1.* = .{ .identifier = 1, .start_time = 0.0, .start_pos = .{ .x = 0.2, .y = 0.3 }, .tracking = true };

    const s2 = table.getAvailable().?;
    s2.* = .{ .identifier = 2, .start_time = 0.1, .start_pos = .{ .x = 0.6, .y = 0.7 }, .tracking = true };

    try std.testing.expectEqual(s1, table.find(1));
    try std.testing.expectEqual(s2, table.find(2));
    try std.testing.expectEqual(@as(usize, 2), table.trackingCount());
}
