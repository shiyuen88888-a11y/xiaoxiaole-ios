import Foundation

/// Pure match-3 logic, direct 1:1 port of Match3Logic.java:
/// 8x8, 6 types, 30 moves per level, target 800 + 700*(level-1), combo multiplier on cascades.
final class Match3Logic {
    static let rows = 8
    static let cols = 8
    static let types = 6

    static let fruitNames = [
        "apple", "banana", "grape", "strawberry", "orange", "blueberry"
    ]

    final class Tile {
        let id: Int
        var type: Int

        init(id: Int, type: Int) {
            self.id = id
            self.type = type
        }
    }

    struct CellPos: Hashable {
        let row: Int
        let col: Int
    }

    struct SpawnInfo {
        let tile: Tile
        let row: Int
        let col: Int
        let spawnRow: Int
    }

    private var nextId = 1

    func makeTile(type: Int) -> Tile {
        let tile = Tile(id: nextId, type: type)
        nextId += 1
        return tile
    }

    func randomType() -> Int {
        Int.random(in: 0..<Self.types)
    }

    func createBoard() -> [[Tile?]] {
        var grid = Array(repeating: Array<Tile?>(repeating: nil, count: Self.cols), count: Self.rows)
        for r in 0..<Self.rows {
            for c in 0..<Self.cols {
                var t: Int
                repeat {
                    t = randomType()
                } while (c >= 2 && grid[r][c - 1]?.type == t && grid[r][c - 2]?.type == t)
                    || (r >= 2 && grid[r - 1][c]?.type == t && grid[r - 2][c]?.type == t)
                grid[r][c] = makeTile(type: t)
            }
        }
        if !hasPossibleMove(grid) {
            _ = shuffleTypes(&grid)
        }
        return grid
    }

    func findMatches(_ grid: [[Tile?]]) -> [CellPos] {
        var found = Array(repeating: Array(repeating: false, count: Self.cols), count: Self.rows)

        // Horizontal
        for r in 0..<Self.rows {
            var c = 0
            while c < Self.cols {
                guard let t = grid[r][c]?.type else {
                    c += 1
                    continue
                }
                var run = 1
                while c + run < Self.cols, grid[r][c + run]?.type == t {
                    run += 1
                }
                if run >= 3 {
                    for k in 0..<run {
                        found[r][c + k] = true
                    }
                }
                c += run
            }
        }

        // Vertical
        for c in 0..<Self.cols {
            var r = 0
            while r < Self.rows {
                guard let t = grid[r][c]?.type else {
                    r += 1
                    continue
                }
                var run = 1
                while r + run < Self.rows, grid[r + run][c]?.type == t {
                    run += 1
                }
                if run >= 3 {
                    for k in 0..<run {
                        found[r + k][c] = true
                    }
                }
                r += run
            }
        }

        var out: [CellPos] = []
        for r in 0..<Self.rows {
            for c in 0..<Self.cols {
                if found[r][c] {
                    out.append(CellPos(row: r, col: c))
                }
            }
        }
        return out
    }

    func swapCells(_ grid: inout [[Tile?]], _ r1: Int, _ c1: Int, _ r2: Int, _ c2: Int) {
        let tmp = grid[r1][c1]
        grid[r1][c1] = grid[r2][c2]
        grid[r2][c2] = tmp
    }

    func hasPossibleMove(_ grid: [[Tile?]]) -> Bool {
        var copy = grid
        let dirs = [(0, 1), (1, 0)]
        for r in 0..<Self.rows {
            for c in 0..<Self.cols {
                for (dr, dc) in dirs {
                    let r2 = r + dr
                    let c2 = c + dc
                    if r2 >= Self.rows || c2 >= Self.cols { continue }
                    swapCells(&copy, r, c, r2, c2)
                    let matched = !findMatches(copy).isEmpty
                    swapCells(&copy, r, c, r2, c2)
                    if matched { return true }
                }
            }
        }
        return false
    }

    func removeCells(_ grid: inout [[Tile?]], cells: [CellPos]) {
        for p in cells {
            grid[p.row][p.col] = nil
        }
    }

    func applyGravityAndRefill(_ grid: inout [[Tile?]]) -> [SpawnInfo] {
        var spawned: [SpawnInfo] = []
        for c in 0..<Self.cols {
            var stack: [Tile] = []
            for r in stride(from: Self.rows - 1, through: 0, by: -1) {
                if let tile = grid[r][c] {
                    stack.append(tile)
                }
            }
            let need = Self.rows - stack.count
            var fresh: [Tile] = []
            for _ in 0..<need {
                fresh.append(makeTile(type: randomType()))
            }
            // stack was collected bottom-to-top, so reverse it to get top-to-bottom below fresh tiles
            let col = fresh + stack.reversed()
            for r in 0..<Self.rows {
                grid[r][c] = col[r]
                if r < need {
                    spawned.append(SpawnInfo(tile: col[r], row: r, col: c, spawnRow: r - need))
                }
            }
        }
        return spawned
    }

    @discardableResult
    func shuffleTypes(_ grid: inout [[Tile?]]) -> Bool {
        var types: [Int] = []
        for r in 0..<Self.rows {
            for c in 0..<Self.cols {
                if let t = grid[r][c]?.type {
                    types.append(t)
                }
            }
        }
        guard types.count == Self.rows * Self.cols else { return false }

        for _ in 0..<300 {
            types.shuffle()
            var k = 0
            for r in 0..<Self.rows {
                for c in 0..<Self.cols {
                    grid[r][c]?.type = types[k]
                    k += 1
                }
            }
            if findMatches(grid).isEmpty && hasPossibleMove(grid) {
                return true
            }
        }

        for _ in 0..<100 {
            let tmp = createBoard()
            if hasPossibleMove(tmp) {
                for r in 0..<Self.rows {
                    for c in 0..<Self.cols {
                        if let t = tmp[r][c]?.type {
                            grid[r][c]?.type = t
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    static func scoreFor(count: Int, combo: Int) -> Int {
        var base = count * 10
        if count >= 5 {
            base += 50
        } else if count >= 4 {
            base += 20
        }
        return base * combo
    }

    static func targetFor(level: Int) -> Int {
        800 + (level - 1) * 700
    }
}
