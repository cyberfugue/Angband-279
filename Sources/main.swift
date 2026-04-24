import Foundation

struct Point: Equatable {
    var x: Int
    var y: Int
}

enum Tile: Character {
    case wall = "#"
    case floor = "."
    case stairs = ">"
}

struct Entity {
    var name: String
    var glyph: Character
    var hp: Int
    var attack: Int
    var position: Point

    var alive: Bool { hp > 0 }
}

struct Room {
    var x: Int
    var y: Int
    var w: Int
    var h: Int

    var center: Point {
        Point(x: x + w / 2, y: y + h / 2)
    }

    func intersects(_ other: Room) -> Bool {
        !(x + w < other.x || other.x + other.w < x || y + h < other.y || other.y + other.h < y)
    }
}

struct Dungeon {
    let width: Int
    let height: Int
    var tiles: [[Tile]]
    var rooms: [Room] = []
    var stairs: Point = .init(x: 1, y: 1)

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.tiles = Array(repeating: Array(repeating: .wall, count: width), count: height)
    }

    func isWalkable(_ p: Point) -> Bool {
        guard p.x >= 0, p.y >= 0, p.x < width, p.y < height else { return false }
        let t = tiles[p.y][p.x]
        return t == .floor || t == .stairs
    }
}

final class Game {
    private let width = 60
    private let height = 22
    private var depth = 1

    private var dungeon = Dungeon(width: 60, height: 22)
    private var player = Entity(name: "Hero", glyph: "@", hp: 35, attack: 7, position: .init(x: 1, y: 1))
    private var monsters: [Entity] = []
    private var log: [String] = ["Welcome to Angband 2.7.9 (Swift Edition)"]
    private var rng = SystemRandomNumberGenerator()

    func run() {
        while player.alive {
            generateLevel()
            while player.alive {
                render()
                guard let command = readCommand() else { continue }
                if command == "q" {
                    print("You abandon your quest at dungeon level \(depth).")
                    return
                }
                processPlayerCommand(command)
                monstersTurn()
                cleanupDeadMonsters()
                if player.position == dungeon.stairs {
                    depth += 1
                    logMessage("You descend to dungeon level \(depth).")
                    player.hp = min(player.hp + 5, 35 + (depth - 1) * 2)
                    break
                }
                if depth >= 8 {
                    render()
                    print("You recovered a legendary relic from depth 8 and won!")
                    return
                }
            }
        }
        render()
        print("You have died in the darkness of Angband.")
    }

    private func generateLevel() {
        dungeon = Dungeon(width: width, height: height)
        monsters.removeAll()

        let roomAttempts = 45
        for _ in 0..<roomAttempts {
            let w = Int.random(in: 4...10, using: &rng)
            let h = Int.random(in: 3...7, using: &rng)
            let x = Int.random(in: 1..<(width - w - 1), using: &rng)
            let y = Int.random(in: 1..<(height - h - 1), using: &rng)
            let room = Room(x: x, y: y, w: w, h: h)
            if dungeon.rooms.contains(where: { room.intersects($0) }) { continue }
            carve(room: room)
            if let prev = dungeon.rooms.last {
                connect(prev.center, room.center)
            }
            dungeon.rooms.append(room)
        }

        guard let first = dungeon.rooms.first, let last = dungeon.rooms.last else {
            fatalError("Failed to generate rooms")
        }
        player.position = first.center
        dungeon.stairs = last.center
        dungeon.tiles[dungeon.stairs.y][dungeon.stairs.x] = .stairs

        for room in dungeon.rooms.dropFirst() {
            let spawnChance = Int.random(in: 0...100, using: &rng)
            if spawnChance < 55 {
                let monster = Entity(
                    name: monsterName(),
                    glyph: "m",
                    hp: Int.random(in: (4 + depth)...(8 + depth * 2), using: &rng),
                    attack: Int.random(in: (2 + depth / 2)...(4 + depth), using: &rng),
                    position: room.center
                )
                monsters.append(monster)
            }
        }

        logMessage("You enter dungeon level \(depth).")
    }

    private func carve(room: Room) {
        for y in room.y..<(room.y + room.h) {
            for x in room.x..<(room.x + room.w) {
                dungeon.tiles[y][x] = .floor
            }
        }
    }

    private func connect(_ a: Point, _ b: Point) {
        var x = a.x
        var y = a.y
        while x != b.x {
            dungeon.tiles[y][x] = .floor
            x += b.x > x ? 1 : -1
        }
        while y != b.y {
            dungeon.tiles[y][x] = .floor
            y += b.y > y ? 1 : -1
        }
        dungeon.tiles[y][x] = .floor
    }

    private func render() {
        print("\u{001B}[2J\u{001B}[H", terminator: "")
        let sightRadius = 8
        for y in 0..<height {
            var line = ""
            for x in 0..<width {
                let p = Point(x: x, y: y)
                let visible = abs(player.position.x - x) + abs(player.position.y - y) <= sightRadius
                if !visible {
                    line.append(" ")
                    continue
                }
                if player.position == p {
                    line.append(player.glyph)
                } else if let monster = monsters.first(where: { $0.position == p && $0.alive }) {
                    line.append(monster.glyph)
                } else if dungeon.stairs == p {
                    line.append(Tile.stairs.rawValue)
                } else {
                    line.append(dungeon.tiles[y][x].rawValue)
                }
            }
            print(line)
        }
        print("Depth: \(depth)   HP: \(player.hp)   Monsters: \(monsters.count)")
        print("Commands: w/a/s/d move, . wait, q quit")
        if let latest = log.last { print("Log: \(latest)") }
    }

    private func readCommand() -> String? {
        FileHandle.standardOutput.write(Data("Action > ".utf8))
        return readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func processPlayerCommand(_ command: String) {
        let delta: Point?
        switch command {
        case "w": delta = Point(x: 0, y: -1)
        case "s": delta = Point(x: 0, y: 1)
        case "a": delta = Point(x: -1, y: 0)
        case "d": delta = Point(x: 1, y: 0)
        case ".":
            logMessage("You wait and listen to the dungeon.")
            return
        default:
            logMessage("Unknown command: \(command)")
            return
        }

        guard let delta else { return }
        let target = Point(x: player.position.x + delta.x, y: player.position.y + delta.y)
        if let idx = monsters.firstIndex(where: { $0.position == target && $0.alive }) {
            playerAttack(monsterIndex: idx)
            return
        }
        if dungeon.isWalkable(target) {
            player.position = target
        }
    }

    private func playerAttack(monsterIndex: Int) {
        let damage = Int.random(in: (player.attack / 2)...player.attack, using: &rng)
        monsters[monsterIndex].hp -= damage
        logMessage("You hit the \(monsters[monsterIndex].name) for \(damage).")
    }

    private func monstersTurn() {
        for i in monsters.indices {
            guard monsters[i].alive else { continue }
            let dx = player.position.x - monsters[i].position.x
            let dy = player.position.y - monsters[i].position.y
            let dist = abs(dx) + abs(dy)
            if dist == 1 {
                let damage = Int.random(in: 1...monsters[i].attack, using: &rng)
                player.hp -= damage
                logMessage("The \(monsters[i].name) hits you for \(damage).")
                continue
            }

            if dist < 9 {
                let step = Point(x: dx == 0 ? 0 : (dx > 0 ? 1 : -1), y: dy == 0 ? 0 : (dy > 0 ? 1 : -1))
                let next = Point(x: monsters[i].position.x + step.x, y: monsters[i].position.y + step.y)
                if dungeon.isWalkable(next) && next != player.position && monsters.allSatisfy({ !$0.alive || $0.position != next }) {
                    monsters[i].position = next
                }
            }
        }
    }

    private func cleanupDeadMonsters() {
        let before = monsters.count
        monsters.removeAll { !$0.alive }
        let removed = before - monsters.count
        if removed > 0 {
            logMessage("You have slain \(removed) foe\(removed == 1 ? "" : "s").")
        }
    }

    private func monsterName() -> String {
        let names = ["Kobold", "Orc", "Wolf", "Cave Spider", "Skeleton", "Dark Elf"]
        return names.randomElement(using: &rng) ?? "Goblin"
    }

    private func logMessage(_ message: String) {
        log.append(message)
        if log.count > 8 { log.removeFirst() }
    }
}

Game().run()
