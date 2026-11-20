import Combine
import SwiftUI

struct LevelEndState: Identifiable {
    let id = UUID()
    let win: Bool
    let level: Int
    let score: Int
    let target: Int
}

final class GameController: ObservableObject {
    @Published var level: Int = 1
    @Published var score: Int = 0
    @Published var moves: Int = 30
    @Published var target: Int = 800
    @Published var bestScore: Int
    @Published var muted: Bool

    @Published var inGame: Bool = false
    @Published var levelEndState: LevelEndState?
    @Published var showComboBanner: Bool = false
    @Published var comboBannerScale: CGFloat = 0.4
    @Published var comboBannerOpacity: Double = 0
    @Published var toastMessage: String?

    @Published private(set) var renderTick: UInt64 = 0

    final class TileView {
        let tile: Match3Logic.Tile
        var row: Int
        var col: Int
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat = 1.0
        var rotation: Double = 0.0
        var clearing: Bool = false
        var clearStart: TimeInterval = 0
        var hinting: Bool = false

        init(tile: Match3Logic.Tile, row: Int, col: Int, cellSize: CGFloat) {
            self.tile = tile
            self.row = row
            self.col = col
            self.x = CGFloat(col) * cellSize
            self.y = CGFloat(row) * cellSize
        }
    }

    struct Popup: Identifiable {
        let id = UUID()
        let text: String
        let col: CGFloat
        let row: CGFloat
        let born: TimeInterval
    }

    private let logic = Match3Logic()
    private let sound = SoundEffects()
    private let defaults = UserDefaults.standard
    private let bestKey = "best"
    private let mutedKey = "muted"

    private(set) var grid: [[Match3Logic.Tile?]] = []
    private(set) var tileViews: [Int: TileView] = [:]
    private(set) var popups: [Popup] = []
    private(set) var selRow: Int = -1
    private(set) var selCol: Int = -1
    private(set) var cellSize: CGFloat = 0

    private var locked: Bool = false
    private var hintUntil: TimeInterval = 0
    private var frameTimer: Timer?
    private var pendingWork: [DispatchWorkItem] = []
    private var toastWork: DispatchWorkItem?

    init() {
        self.bestScore = defaults.integer(forKey: bestKey)
        self.muted = defaults.bool(forKey: mutedKey)
    }

    deinit {
        cancelAllWork()
    }

    func toggleMute() {
        muted.toggle()
        defaults.set(muted, forKey: mutedKey)
    }

    func updateBoardSize(_ size: CGFloat) {
        let newCell = size / CGFloat(Match3Logic.cols)
        guard newCell > 0, abs(newCell - cellSize) > 0.1 else { return }
        cellSize = newCell
        for tv in tileViews.values {
            tv.x = CGFloat(tv.col) * cellSize
            tv.y = CGFloat(tv.row) * cellSize
        }
        renderTick &+= 1
    }

    func startGame() {
        inGame = true
        startLevel(1)
    }

    func backToStart() {
        cancelAllWork()
        inGame = false
        levelEndState = nil
    }

    func startLevel(_ lv: Int) {
        cancelAllWork()
        level = lv
        score = 0
        moves = 30
        target = Match3Logic.targetFor(level: lv)
        levelEndState = nil
        grid = logic.createBoard()
        tileViews.removeAll()
        popups.removeAll()
        selRow = -1
        selCol = -1
        locked = false

        for r in 0..<Match3Logic.rows {
            for c in 0..<Match3Logic.cols {
                if let tile = grid[r][c] {
                    tileViews[tile.id] = TileView(tile: tile, row: r, col: c, cellSize: cellSize)
                }
            }
        }
        renderTick &+= 1
    }

    func restartLevel() {
        startLevel(level)
        showToast("已重新开始")
    }

    func showHint() {
        guard !locked, !grid.isEmpty else { return }
        let dirs = [(0, 1), (1, 0)]
        for r in 0..<Match3Logic.rows {
            for c in 0..<Match3Logic.cols {
                for (dr, dc) in dirs {
                    let r2 = r + dr
                    let c2 = c + dc
                    if r2 >= Match3Logic.rows || c2 >= Match3Logic.cols { continue }
                    logic.swapCells(&grid, r, c, r2, c2)
                    let ok = !logic.findMatches(grid).isEmpty
                    logic.swapCells(&grid, r, c, r2, c2)
                    if ok {
                        if let t1 = grid[r][c], let v1 = tileViews[t1.id] {
                            v1.hinting = true
                        }
                        if let t2 = grid[r2][c2], let v2 = tileViews[t2.id] {
                            v2.hinting = true
                        }
                        hintUntil = ProcessInfo.processInfo.systemUptime + 1.5
                        scheduleFrameLoop()
                        return
                    }
                }
            }
        }
    }

    func handleTap(row: Int, col: Int) {
        guard !locked, !grid.isEmpty else { return }
        guard row >= 0, row < Match3Logic.rows, col >= 0, col < Match3Logic.cols else { return }

        if selRow == -1 {
            selRow = row
            selCol = col
            renderTick &+= 1
            return
        }
        if selRow == row && selCol == col {
            selRow = -1
            selCol = -1
            renderTick &+= 1
            return
        }
        let dr = abs(selRow - row)
        let dc = abs(selCol - col)
        if dr + dc == 1 {
            let sr = selRow
            let sc = selCol
            selRow = -1
            selCol = -1
            trySwap(sr, sc, row, col)
        } else {
            selRow = row
            selCol = col
            renderTick &+= 1
        }
    }

    func handleSwipe(fromRow: Int, fromCol: Int, toRow: Int, toCol: Int) {
        guard !locked, !grid.isEmpty else { return }
        guard fromRow >= 0, fromRow < Match3Logic.rows, fromCol >= 0, fromCol < Match3Logic.cols else { return }
        guard toRow >= 0, toRow < Match3Logic.rows, toCol >= 0, toCol < Match3Logic.cols else { return }
        let dr = abs(fromRow - toRow)
        let dc = abs(fromCol - toCol)
        if dr + dc == 1 {
            trySwap(fromRow, fromCol, toRow, toCol)
        }
    }

    func showToast(_ message: String) {
        toastWork?.cancel()
        toastMessage = message
        let work = DispatchWorkItem { [weak self] in
            self?.toastMessage = nil
        }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }

    // MARK: - Private Game Flow

    private func trySwap(_ r1: Int, _ c1: Int, _ r2: Int, _ c2: Int) {
        guard !locked, !grid.isEmpty else { return }
        locked = true
        selRow = -1
        selCol = -1
        logic.swapCells(&grid, r1, c1, r2, c2)
        syncTileViews()
        emitSound(.swap)
        scheduleFrameLoop()

        scheduleAfter(0.20) { [weak self] in
            guard let self else { return }
            let matches = self.logic.findMatches(self.grid)
            if matches.isEmpty {
                self.logic.swapCells(&self.grid, r1, c1, r2, c2)
                self.syncTileViews()
                self.scheduleFrameLoop()
                self.scheduleAfter(0.20) { [weak self] in
                    self?.locked = false
                }
                return
            }
            self.moves -= 1
            self.runCascade(combo: 0)
        }
    }

    private func runCascade(combo: Int) {
        let matches = logic.findMatches(grid)
        if matches.isEmpty {
            finishCascade()
            return
        }
        let nextCombo = combo + 1
        let pts = Match3Logic.scoreFor(count: matches.count, combo: nextCombo)
        score += pts
        if score > bestScore {
            bestScore = score
            defaults.set(bestScore, forKey: bestKey)
        }

        let mid = matches[matches.count / 2]
        let now = ProcessInfo.processInfo.systemUptime
        let popupText = "+\(pts)" + (nextCombo >= 2 ? " 连锁x\(nextCombo)" : "")
        popups.append(Popup(text: popupText, col: CGFloat(mid.col), row: CGFloat(mid.row), born: now))

        for p in matches {
            if let tile = grid[p.row][p.col], let tv = tileViews[tile.id] {
                tv.clearing = true
                tv.clearStart = now
            }
        }

        if nextCombo >= 3 {
            triggerComboBanner()
            emitSound(.perfect)
        } else {
            emitSound(.match)
        }
        scheduleFrameLoop()

        scheduleAfter(0.26) { [weak self] in
            guard let self else { return }
            self.logic.removeCells(&self.grid, cells: matches)
            for p in matches {
                if let removedKey = self.tileViews.first(where: {
                    $0.value.row == p.row && $0.value.col == p.col && $0.value.clearing
                })?.key {
                    self.tileViews.removeValue(forKey: removedKey)
                }
            }
            let spawned = self.logic.applyGravityAndRefill(&self.grid)
            for s in spawned {
                let tv = TileView(tile: s.tile, row: s.row, col: s.col, cellSize: self.cellSize)
                tv.y = CGFloat(s.spawnRow) * self.cellSize
                self.tileViews[s.tile.id] = tv
            }
            self.syncTileViews()
            self.scheduleFrameLoop()
            self.scheduleAfter(0.30) { [weak self] in
                self?.runCascade(combo: nextCombo)
            }
        }
    }

    private func finishCascade() {
        if score >= target {
            emitSound(.win)
            locked = false
            levelEndState = LevelEndState(win: true, level: level, score: score, target: target)
            return
        }
        if moves <= 0 {
            emitSound(.fail)
            locked = false
            levelEndState = LevelEndState(win: false, level: level, score: score, target: target)
            return
        }
        if !logic.hasPossibleMove(grid) {
            showToast("没有可消除的了，正在洗牌…")
            scheduleAfter(0.40) { [weak self] in
                guard let self else { return }
                self.logic.shuffleTypes(&self.grid)
                self.syncTileViews()
                self.scheduleFrameLoop()
                self.locked = false
            }
            return
        }
        locked = false
    }

    private func syncTileViews() {
        for r in 0..<Match3Logic.rows {
            for c in 0..<Match3Logic.cols {
                guard let t = grid[r][c], let tv = tileViews[t.id] else { continue }
                tv.row = r
                tv.col = c
            }
        }
    }

    private func emitSound(_ kind: SoundKind) {
        if !muted {
            sound.play(kind)
        }
    }

    private func triggerComboBanner() {
        showComboBanner = true
        comboBannerScale = 0.4
        comboBannerOpacity = 0.0
        withAnimation(.easeOut(duration: 0.25)) {
            comboBannerScale = 1.25
            comboBannerOpacity = 1.0
        }
        scheduleAfter(0.25) { [weak self] in
            withAnimation(.easeInOut(duration: 0.20)) {
                self?.comboBannerScale = 1.0
            }
        }
        scheduleAfter(0.70) { [weak self] in
            withAnimation(.easeOut(duration: 0.30)) {
                self?.comboBannerOpacity = 0.0
            }
        }
        scheduleAfter(1.02) { [weak self] in
            self?.showComboBanner = false
        }
    }

    // MARK: - 60fps Frame Loop

    private func scheduleFrameLoop() {
        guard frameTimer == nil else { return }
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let busy = self.updateFrame()
            self.renderTick &+= 1
            if !busy {
                timer.invalidate()
                self.frameTimer = nil
            }
        }
        if let frameTimer {
            RunLoop.main.add(frameTimer, forMode: .common)
        }
    }

    private func updateFrame() -> Bool {
        var busy = false
        let now = ProcessInfo.processInfo.systemUptime

        for tv in tileViews.values {
            let tx = CGFloat(tv.col) * cellSize
            let ty = CGFloat(tv.row) * cellSize
            if abs(tv.x - tx) > 0.5 || abs(tv.y - ty) > 0.5 {
                tv.x += (tx - tv.x) * 0.4
                tv.y += (ty - tv.y) * 0.4
                if abs(tv.x - tx) < 0.5 { tv.x = tx }
                if abs(tv.y - ty) < 0.5 { tv.y = ty }
                busy = true
            }
            if tv.clearing {
                let p = min(1.0, max(0.0, (now - tv.clearStart) / 0.24))
                if p < 1.0 {
                    busy = true
                }
                tv.scale = CGFloat(1.0 - p)
                tv.rotation = 120.0 * p
            } else if tv.hinting {
                if now < hintUntil {
                    let phase = (now.truncatingRemainder(dividingBy: 0.5)) / 0.5 * Double.pi * 2.0
                    tv.scale = CGFloat(1.0 + 0.18 * sin(phase))
                    busy = true
                } else {
                    tv.hinting = false
                    tv.scale = 1.0
                }
            } else if tv.scale != 1.0 || tv.rotation != 0.0 {
                tv.scale = 1.0
                tv.rotation = 0.0
            }
        }

        for i in stride(from: popups.count - 1, through: 0, by: -1) {
            if now - popups[i].born > 0.85 {
                popups.remove(at: i)
            } else {
                busy = true
            }
        }

        return busy
    }

    private func scheduleAfter(_ delay: TimeInterval, block: @escaping () -> Void) {
        let item = DispatchWorkItem(block: block)
        pendingWork.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func cancelAllWork() {
        frameTimer?.invalidate()
        frameTimer = nil
        for item in pendingWork {
            item.cancel()
        }
        pendingWork.removeAll()
    }
}

struct BoardView: View {
    @ObservedObject var controller: GameController
    @State private var downCell: Match3Logic.CellPos?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / CGFloat(Match3Logic.cols)

            ZStack {
                Canvas { context, size in
                    let _ = controller.renderTick
                    guard cell > 0 else { return }

                    let boardRect = CGRect(x: 0, y: 0, width: side, height: side)
                    let boardPath = Path(roundedRect: boardRect, cornerRadius: 18)
                    context.fill(boardPath, with: .color(Color.white.opacity(0.32)))
                    context.stroke(boardPath, with: .color(Color.white.opacity(0.50)), lineWidth: 2)

                    let gap = cell * 0.04
                    let fruitImages = Match3Logic.fruitNames.map { context.resolve(Image($0)) }

                    for tv in controller.tileViews.values {
                        let typeIdx = tv.tile.type
                        guard typeIdx >= 0, typeIdx < fruitImages.count else { continue }
                        let img = fruitImages[typeIdx]
                        let cx = tv.x + cell / 2
                        let cy = tv.y + cell / 2
                        let half = (cell - gap * 2) / 2 * tv.scale
                        guard half > 0 else { continue }

                        context.drawLayer { layerCtx in
                            layerCtx.translateBy(x: cx, y: cy)
                            if tv.rotation != 0 {
                                layerCtx.rotate(by: .degrees(tv.rotation))
                            }
                            let rect = CGRect(x: -half, y: -half, width: half * 2, height: half * 2)
                            let clipPath = Path(roundedRect: rect, cornerRadius: (half * 2) * 0.11)
                            layerCtx.clip(to: clipPath)
                            layerCtx.draw(img, in: rect)
                        }

                        if tv.row == controller.selRow && tv.col == controller.selCol {
                            let selHalf = (cell - gap * 2) / 2 * 1.12
                            let selRect = CGRect(
                                x: cx - selHalf,
                                y: cy - selHalf,
                                width: selHalf * 2,
                                height: selHalf * 2
                            )
                            let selPath = Path(roundedRect: selRect, cornerRadius: 11)
                            context.stroke(selPath, with: .color(Color.white.opacity(0.55)), lineWidth: 5)
                            context.stroke(selPath, with: .color(.white), lineWidth: 3)
                        }
                    }

                    let now = ProcessInfo.processInfo.systemUptime
                    for p in controller.popups {
                        let age = (now - p.born) / 0.80
                        if age >= 1.0 { continue }
                        let px = (p.col + 0.5) * cell
                        let py = (p.row + 0.5) * cell - CGFloat(age) * 46
                        let text = Text(p.text)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white.opacity(max(0, 1.0 - age)))
                        context.draw(text, at: CGPoint(x: px, y: py), anchor: .center)
                    }
                }
                .frame(width: side, height: side)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if downCell == nil {
                                downCell = cellFrom(point: value.startLocation, cell: cell)
                            }
                        }
                        .onEnded { value in
                            defer { downCell = nil }
                            guard let down = downCell else { return }
                            let dx = value.translation.width
                            let dy = value.translation.height
                            let dist = hypot(dx, dy)

                            if dist < cell * 0.30 {
                                if let up = cellFrom(point: value.location, cell: cell) {
                                    if down == up {
                                        controller.handleTap(row: up.row, col: up.col)
                                    } else if abs(down.row - up.row) + abs(down.col - up.col) == 1 {
                                        controller.handleSwipe(fromRow: down.row, fromCol: down.col, toRow: up.row, toCol: up.col)
                                    } else {
                                        controller.handleTap(row: up.row, col: up.col)
                                    }
                                }
                            } else {
                                var targetRow = down.row
                                var targetCol = down.col
                                if abs(dx) > abs(dy) {
                                    targetCol += dx > 0 ? 1 : -1
                                } else {
                                    targetRow += dy > 0 ? 1 : -1
                                }
                                controller.handleSwipe(fromRow: down.row, fromCol: down.col, toRow: targetRow, toCol: targetCol)
                            }
                        }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                controller.updateBoardSize(side)
            }
            .onChange(of: side) { newSide in
                controller.updateBoardSize(newSide)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func cellFrom(point: CGPoint, cell: CGFloat) -> Match3Logic.CellPos? {
        guard cell > 0 else { return nil }
        let c = Int(floor(point.x / cell))
        let r = Int(floor(point.y / cell))
        guard r >= 0, r < Match3Logic.rows, c >= 0, c < Match3Logic.cols else { return nil }
        return Match3Logic.CellPos(row: r, col: c)
    }
}
