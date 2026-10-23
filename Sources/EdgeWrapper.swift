import AppKit

/// Watches mouse motion and teleports the cursor from the outermost left/right edge of the
/// desktop to the opposite one.
final class EdgeWrapper {
    var isEnabled = true
    var wrapsWhileDragging = false
    /// When set, a lone display (mirrored displays count as one) keeps its normal hard edges.
    var requiresMultipleDisplays = true
    /// Set while something else (e.g. the pie menu) owns the cursor.
    var isSuspended = false

    private var monitors: [Any] = []
    private var lastWarp = Date.distantPast

    func start() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] in self?.handle($0) }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] in self?.handle($0); return $0 }) {
            monitors.append(local)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    private func handle(_ event: NSEvent) {
        guard isEnabled, !isSuspended else { return }
        guard event.type == .mouseMoved || wrapsWhileDragging else { return }
        let dx = event.deltaX
        guard dx != 0, Date().timeIntervalSince(lastWarp) > 0.1 else { return }

        let displays = Displays.all()
        guard !requiresMultipleDisplays || displays.count > 1 else { return }
        let p = Displays.cursorLocation
        guard let source = Displays.display(at: p, in: displays) else { return }
        let f = source.frame

        if dx > 0, p.x >= f.maxX - 1.5, !displays.contains(where: { $0.frame.minX >= f.maxX - 1 }) {
            wrap(from: p, on: source, toward: .left, in: displays)
        } else if dx < 0, p.x <= f.minX + 1.5, !displays.contains(where: { $0.frame.maxX <= f.minX + 1 }) {
            wrap(from: p, on: source, toward: .right, in: displays)
        }
    }

    /// Moves the cursor to the outermost edge of the desktop on the given side.
    private func wrap(from p: CGPoint, on source: Display, toward side: Direction, in displays: [Display]) {
        let edge = side == .left
            ? displays.map(\.frame.minX).min()!
            : displays.map(\.frame.maxX).max()!
        let candidates = displays.filter {
            abs((side == .left ? $0.frame.minX : $0.frame.maxX) - edge) < 1
        }
        let target = candidates.first { $0.frame.minY <= p.y && p.y < $0.frame.maxY }
            ?? candidates.min { abs($0.center.y - p.y) < abs($1.center.y - p.y) }!

        var y = p.y
        if !(target.frame.minY..<target.frame.maxY).contains(y) {
            // Keep the same relative height when the target display doesn't span this row.
            let t = (p.y - source.frame.minY) / source.frame.height
            y = target.frame.minY + t * (target.frame.height - 1)
        }
        let x = side == .left ? target.frame.minX + 1 : target.frame.maxX - 2

        lastWarp = Date()
        Displays.warp(to: CGPoint(x: x, y: y))
    }
}
