import Foundation

struct Point: Hashable {
    var x: Int
    var y: Int

    static func +(lhs: Point, rhs: Point) -> Point {
        Point(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    func manhattanDistance(to other: Point) -> Int {
        abs(x - other.x) + abs(y - other.y)
    }
}

enum Tile: Character {
    case wall = "#"
    case floor = "."
    case closedDoor = "+"
    case stairsDown = ">"

    var walkable: Bool {
        switch self {
        case .floor, .stairsDown:
            return true
        case .wall, .closedDoor:
            return false
        }
    }

    var transparent: Bool {
        switch self {
        case .wall, .closedDoor:
            return false
        case .floor, .stairsDown:
            return true
        }
    }
}

enum ItemType: String {
    case potionHealing = "Potion of Healing"
    case ration = "Ration of Food"

    var glyph: Character { "!" }
}

struct Item {
    var type: ItemType
    var position: Point
}

struct Room {
    var x: Int
    var y: Int
    var width: Int
    var height: Int

    var center: Point {
        Point(x: x + width / 2, y: y + height / 2)
    }

    func intersects(_ other: Room) -> Bool {
        !(x + width < other.x || other.x + other.width < x || y + height < other.y || other.y + other.height < y)
    }
}

struct Actor {
    var name: String
    var glyph: Character
    var position: Point
    var hp: Int
    var maxHP: Int
    var attackMin: Int
    var attackMax: Int
    var level: Int
    var xp: Int

    var alive: Bool { hp > 0 }

    mutating func gainXP(_ amount: Int) -> Bool {
        xp += amount
        let nextLevelThreshold = level * 30
        if xp >= nextLevelThreshold {
            level += 1
            xp = 0
            maxHP += 4
            hp = maxHP
            attackMin += 1
            attackMax += 1
            return true
        }
        return false
    }
}

struct DungeonLevel {
    let width: Int
    let height: Int
    var depth: Int
    var tiles: [[Tile]]
    var rooms: [Room]
    var monsters: [Actor]
    var items: [Item]
    var stairsDown: Point

    init(width: Int, height: Int, depth: Int) {
        self.width = width
        self.height = height
        self.depth = depth
        self.tiles = Array(repeating: Array(repeating: .wall, count: width), count: height)
        self.rooms = []
        self.monsters = []
        self.items = []
        self.stairsDown = Point(x: 1, y: 1)
    }

    func inBounds(_ point: Point) -> Bool {
        point.x >= 0 && point.y >= 0 && point.x < width && point.y < height
    }

    func tile(at point: Point) -> Tile {
        tiles[point.y][point.x]
    }

    mutating func setTile(_ tile: Tile, at point: Point) {
        tiles[point.y][point.x] = tile
    }

    func walkable(_ point: Point) -> Bool {
        inBounds(point) && tile(at: point).walkable
    }
}

final class NativeSwiftAngband {
    private let width = 72
    private let height = 24
    private let maxDepth = 12
    private let sightRadius = 9

    private var rng = SystemRandomNumberGenerator()
    private var level = DungeonLevel(width: 72, height: 24, depth: 1)
    private var player = Actor(
        name: "Dunedain Ranger",
        glyph: "@",
        position: Point(x: 1, y: 1),
        hp: 28,
        maxHP: 28,
        attackMin: 3,
        attackMax: 7,
        level: 1,
        xp: 0
    )
    private var messageLog: [String] = ["Welcome to Native Swift Angband."]
    private var explored: Set<Point> = []
    private var inventory: [ItemType] = [.ration]

    func run() {
        generateLevel(depth: 1)
        gameLoop()
    }

    private func gameLoop() {
        while player.alive {
            render()
            guard let command = prompt(), !command.isEmpty else { continue }

            if command == "q" {
                print("You leave the dungeon alive at depth \(level.depth).")
                return
            }

            process(command: command)
            if !player.alive { break }

            monstersAct()
            pickupItemIfPresent()

            if player.position == level.stairsDown {
                if level.depth >= maxDepth {
                    render()
                    print("You claim victory from the deeps of Angband!")
                    return
                }
                generateLevel(depth: level.depth + 1)
                log("You descend to depth \(level.depth).")
            }
        }

        render()
        print("You were slain in darkness at depth \(level.depth).")
    }

    private func process(command: String) {
        switch command {
        case "w", "a", "s", "d":
            let delta = direction(command)
            tryMovePlayer(by: delta)
        case ".":
            log("You wait cautiously.")
        case "g":
            pickupItemIfPresent(forceMessage: true)
        case "i":
            showInventory()
        case "u":
            useItem()
        case "?":
            log("Commands: wasd move, g get, i inventory, u use, . wait, q quit")
        default:
            log("Unknown command '\(command)'.")
        }
    }

    private func direction(_ command: String) -> Point {
        switch command {
        case "w": return Point(x: 0, y: -1)
        case "s": return Point(x: 0, y: 1)
        case "a": return Point(x: -1, y: 0)
        default: return Point(x: 1, y: 0)
        }
    }

    private func tryMovePlayer(by delta: Point) {
        let target = player.position + delta
        guard level.inBounds(target) else { return }

        if let monsterIndex = level.monsters.firstIndex(where: { $0.position == target && $0.alive }) {
            attackMonster(at: monsterIndex)
            return
        }

        let tile = level.tile(at: target)
        switch tile {
        case .closedDoor:
            level.setTile(.floor, at: target)
            log("You open the door.")
        default:
            if tile.walkable {
                player.position = target
            }
        }
    }

    private func attackMonster(at index: Int) {
        let damage = Int.random(in: player.attackMin...player.attackMax, using: &rng)
        level.monsters[index].hp -= damage
        log("You hit \(level.monsters[index].name) for \(damage).")

        if !level.monsters[index].alive {
            let deadName = level.monsters[index].name
            let xpGain = Int.random(in: 8...16, using: &rng)
            if player.gainXP(xpGain) {
                log("You reached level \(player.level)!")
            }
            log("You have slain \(deadName).")
        }
    }

    private func monstersAct() {
        for idx in level.monsters.indices {
            guard level.monsters[idx].alive else { continue }

            let distance = level.monsters[idx].position.manhattanDistance(to: player.position)
            if distance == 1 {
                let damage = Int.random(in: level.monsters[idx].attackMin...level.monsters[idx].attackMax, using: &rng)
                player.hp -= damage
                log("\(level.monsters[idx].name) hits you for \(damage).")
                continue
            }

            if distance <= 8 {
                let dx = player.position.x - level.monsters[idx].position.x
                let dy = player.position.y - level.monsters[idx].position.y
                let step = Point(x: dx == 0 ? 0 : (dx > 0 ? 1 : -1), y: dy == 0 ? 0 : (dy > 0 ? 1 : -1))
                let candidate = level.monsters[idx].position + step
                let occupied = level.monsters.enumerated().contains { $0.offset != idx && $0.element.alive && $0.element.position == candidate }
                if level.walkable(candidate) && !occupied && candidate != player.position {
                    level.monsters[idx].position = candidate
                }
            }
        }

        level.monsters.removeAll { !$0.alive }
    }

    private func pickupItemIfPresent(forceMessage: Bool = false) {
        guard let idx = level.items.firstIndex(where: { $0.position == player.position }) else {
            if forceMessage { log("There is nothing here to pick up.") }
            return
        }
        let item = level.items.remove(at: idx)
        inventory.append(item.type)
        log("You pick up \(item.type.rawValue).")
    }

    private func showInventory() {
        if inventory.isEmpty {
            log("Inventory is empty.")
            return
        }
        let listing = inventory.enumerated().map { "\($0.offset + 1): \($0.element.rawValue)" }.joined(separator: ", ")
        log("Inventory: \(listing)")
    }

    private func useItem() {
        guard let idx = inventory.firstIndex(of: .potionHealing) else {
            log("You have no healing potion.")
            return
        }
        inventory.remove(at: idx)
        let heal = Int.random(in: 8...14, using: &rng)
        player.hp = min(player.maxHP, player.hp + heal)
        log("You quaff a potion and recover \(heal) HP.")
    }

    private func generateLevel(depth: Int) {
        level = DungeonLevel(width: width, height: height, depth: depth)
        explored.removeAll()

        let attempts = 70
        for _ in 0..<attempts {
            let w = Int.random(in: 5...12, using: &rng)
            let h = Int.random(in: 4...8, using: &rng)
            let x = Int.random(in: 1..<(width - w - 1), using: &rng)
            let y = Int.random(in: 1..<(height - h - 1), using: &rng)
            let room = Room(x: x, y: y, width: w, height: h)
            guard !level.rooms.contains(where: { room.intersects($0) }) else { continue }

            carve(room)
            if let previous = level.rooms.last {
                connect(previous.center, room.center)
            }
            level.rooms.append(room)
        }

        guard let first = level.rooms.first, let last = level.rooms.last else {
            fatalError("Level generation failed")
        }

        player.position = first.center
        level.stairsDown = last.center
        level.setTile(.stairsDown, at: level.stairsDown)

        for room in level.rooms.dropFirst() {
            if Int.random(in: 0...100, using: &rng) < 60 {
                level.monsters.append(randomMonster(at: room.center, depth: depth))
            }
            if Int.random(in: 0...100, using: &rng) < 35 {
                let itemType: ItemType = Int.random(in: 0...100, using: &rng) < 55 ? .potionHealing : .ration
                level.items.append(Item(type: itemType, position: Point(x: room.center.x + Int.random(in: -1...1, using: &rng), y: room.center.y)))
            }
        }

        placeDoors()
        log("You enter dungeon depth \(depth).")
    }

    private func randomMonster(at point: Point, depth: Int) -> Actor {
        let roster = ["Kobold", "Orc", "Cave spider", "Warg", "Dark elf", "Young troll"]
        let name = roster.randomElement(using: &rng) ?? "Goblin"
        let base = depth + Int.random(in: 0...2, using: &rng)
        return Actor(
            name: name,
            glyph: "m",
            position: point,
            hp: 6 + base * 2,
            maxHP: 6 + base * 2,
            attackMin: 1 + depth / 2,
            attackMax: 3 + depth,
            level: depth,
            xp: 0
        )
    }

    private func carve(_ room: Room) {
        for y in room.y..<(room.y + room.height) {
            for x in room.x..<(room.x + room.width) {
                level.setTile(.floor, at: Point(x: x, y: y))
            }
        }
    }

    private func connect(_ a: Point, _ b: Point) {
        var x = a.x
        var y = a.y

        while x != b.x {
            level.setTile(.floor, at: Point(x: x, y: y))
            x += b.x > x ? 1 : -1
        }
        while y != b.y {
            level.setTile(.floor, at: Point(x: x, y: y))
            y += b.y > y ? 1 : -1
        }
        level.setTile(.floor, at: Point(x: x, y: y))
    }

    private func placeDoors() {
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let point = Point(x: x, y: y)
                guard level.tile(at: point) == .floor else { continue }

                let left = level.tile(at: Point(x: x - 1, y: y))
                let right = level.tile(at: Point(x: x + 1, y: y))
                let up = level.tile(at: Point(x: x, y: y - 1))
                let down = level.tile(at: Point(x: x, y: y + 1))

                let horizontalPassage = (left == .wall && right == .wall && up.walkable && down.walkable)
                let verticalPassage = (up == .wall && down == .wall && left.walkable && right.walkable)

                if (horizontalPassage || verticalPassage) && Int.random(in: 0...100, using: &rng) < 8 {
                    level.setTile(.closedDoor, at: point)
                }
            }
        }
    }

    private func computeVisibleTiles() -> Set<Point> {
        var visible: Set<Point> = []
        for y in 0..<height {
            for x in 0..<width {
                let point = Point(x: x, y: y)
                if player.position.manhattanDistance(to: point) > sightRadius { continue }
                if hasLineOfSight(from: player.position, to: point) {
                    visible.insert(point)
                }
            }
        }
        return visible
    }

    private func hasLineOfSight(from start: Point, to end: Point) -> Bool {
        var x0 = start.x
        var y0 = start.y
        let x1 = end.x
        let y1 = end.y

        let dx = abs(x1 - x0)
        let dy = -abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var error = dx + dy

        while true {
            let p = Point(x: x0, y: y0)
            if p != start && !level.tile(at: p).transparent {
                return p == end
            }
            if x0 == x1 && y0 == y1 { return true }
            let e2 = 2 * error
            if e2 >= dy {
                if x0 == x1 { break }
                error += dy
                x0 += sx
            }
            if e2 <= dx {
                if y0 == y1 { break }
                error += dx
                y0 += sy
            }
        }
        return true
    }

    private func render() {
        print("\u{001B}[2J\u{001B}[H", terminator: "")
        let visible = computeVisibleTiles()
        explored.formUnion(visible)

        for y in 0..<height {
            var row = ""
            for x in 0..<width {
                let point = Point(x: x, y: y)
                if visible.contains(point) {
                    if player.position == point {
                        row.append(player.glyph)
                    } else if let monster = level.monsters.first(where: { $0.position == point && $0.alive }) {
                        row.append(monster.glyph)
                    } else if let item = level.items.first(where: { $0.position == point }) {
                        row.append(item.type.glyph)
                    } else {
                        row.append(level.tile(at: point).rawValue)
                    }
                } else if explored.contains(point) {
                    row.append(level.tile(at: point) == .wall ? " " : "·")
                } else {
                    row.append(" ")
                }
            }
            print(row)
        }

        print("Depth: \(level.depth)/\(maxDepth)  HP: \(player.hp)/\(player.maxHP)  XLvl: \(player.level)  XP: \(player.xp)")
        print("Commands: wasd move, g get, i inv, u use, . wait, ? help, q quit")
        if let last = messageLog.last {
            print("Log: \(last)")
        }
    }

    private func prompt() -> String? {
        FileHandle.standardOutput.write(Data("Action > ".utf8))
        return readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func log(_ message: String) {
        messageLog.append(message)
        if messageLog.count > 12 {
            messageLog.removeFirst(messageLog.count - 12)
        }
    }
}

NativeSwiftAngband().run()
