import Foundation
import CoreGraphics

// MARK: - BreadboardHole

/// A single hole on a standard solderless breadboard.
struct BreadboardHole: Equatable {
    /// Row number (1–63 for standard 830-point board)
    let row: Int
    /// Column letter ("a"–"j") or rail identifier ("+", "-")
    let column: String
    /// Position in canonical board-space coordinates (0...1, origin bottom-left)
    let canonicalPosition: CGPoint
    /// Whether this hole is on a power rail
    let isPowerRail: Bool
}

// MARK: - BreadboardGrid

/// Parametric model of a standard 830-point solderless breadboard.
///
/// The grid encodes rows 1–63, columns a–j (a–e left bank, f–j right bank
/// separated by a center gap), and 4 power rails (top/bottom × +/-).
///
/// All positions use a canonical coordinate system with origin (0,0) at the
/// bottom-left of the board and (1,1) at the top-right.
final class BreadboardGrid {

    /// Total number of rows (63 for a standard full-size board)
    let rows: Int

    /// All holes indexed for nearest-neighbor lookup
    private let holes: [BreadboardHole]

    /// Column letters and their canonical x-positions
    private static let columnPositions: [(String, CGFloat)] = [
        ("a", 0.08), ("b", 0.16), ("c", 0.24), ("d", 0.32), ("e", 0.40),
        // center gap at ~0.50
        ("f", 0.60), ("g", 0.68), ("h", 0.76), ("i", 0.84), ("j", 0.92)
    ]

    /// Power rail x-positions: (side, polarity, x)
    private static let railPositions: [(String, String, CGFloat)] = [
        ("L", "+", 0.02), ("L", "-", 0.05),
        ("R", "+", 0.95), ("R", "-", 0.98)
    ]

    /// Standard 830-point breadboard with 63 rows
    static let standard = BreadboardGrid(rows: 63)

    /// Creates a breadboard grid model.
    ///
    /// - Parameter rows: Number of rows (default 63 for standard full-size board)
    init(rows: Int = 63) {
        self.rows = rows
        var allHoles: [BreadboardHole] = []
        allHoles.reserveCapacity(rows * 10 + rows * 4)

        let rowSpacing = 0.90 / CGFloat(max(rows - 1, 1))
        let rowBase: CGFloat = 0.05

        // Main grid holes (a–j × rows)
        for row in 1...rows {
            let y = rowBase + CGFloat(row - 1) * rowSpacing
            for (col, x) in Self.columnPositions {
                allHoles.append(BreadboardHole(
                    row: row,
                    column: col,
                    canonicalPosition: CGPoint(x: x, y: y),
                    isPowerRail: false
                ))
            }
        }

        // Power rail holes (run the full length of the board)
        for row in 1...rows {
            let y = rowBase + CGFloat(row - 1) * rowSpacing
            for (_, polarity, x) in Self.railPositions {
                allHoles.append(BreadboardHole(
                    row: row,
                    column: polarity,
                    canonicalPosition: CGPoint(x: x, y: y),
                    isPowerRail: true
                ))
            }
        }

        self.holes = allHoles
    }

    // MARK: - Public API

    /// Returns the nearest hole to a point in canonical board-space coordinates.
    ///
    /// - Parameter point: Position in canonical coordinates (0...1)
    /// - Returns: The nearest hole and Euclidean distance, or `nil` if no holes exist
    func nearestHole(to point: CGPoint) -> (hole: BreadboardHole, distance: CGFloat)? {
        var best: BreadboardHole?
        var bestDist = CGFloat.greatestFiniteMagnitude

        for hole in holes {
            let dx = hole.canonicalPosition.x - point.x
            let dy = hole.canonicalPosition.y - point.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < bestDist {
                bestDist = dist
                best = hole
            }
        }

        guard let found = best else { return nil }
        return (found, bestDist)
    }

    /// Returns the human-readable label for a breadboard hole.
    ///
    /// - Format: "Row 12F" for main grid, "Rail +" / "Rail -" for power rails
    /// - Parameter hole: The breadboard hole to label
    /// - Returns: A formatted label string
    func label(for hole: BreadboardHole) -> String {
        if hole.isPowerRail {
            return "Rail \(hole.column)"
        }
        return "Row \(hole.row)\(hole.column.uppercased())"
    }

    /// Returns the canonical position for a given row and column.
    ///
    /// - Parameters:
    ///   - row: Row number (1–63)
    ///   - column: Column letter ("a"–"j") or polarity ("+", "-")
    /// - Returns: Position in canonical coordinates, or `nil` if not found
    func canonicalPosition(row: Int, column: String) -> CGPoint? {
        let col = column.lowercased()
        return holes.first { $0.row == row && $0.column == col }?.canonicalPosition
    }

    /// Returns the canonical position for a label string like "Row 12F" or "Rail +".
    ///
    /// - Parameter label: Human-readable hole label
    /// - Returns: Position in canonical coordinates, or `nil` if the label is invalid
    func position(for label: String) -> CGPoint? {
        if label.hasPrefix("Rail ") {
            let polarity = String(label.dropFirst(5))
            // Return the midpoint of the rail
            return canonicalPosition(row: rows / 2, column: polarity)
        }

        // Parse "Row 12F" format
        guard label.hasPrefix("Row ") else { return nil }
        let rest = label.dropFirst(4)
        guard let lastChar = rest.last else { return nil }
        let col = String(lastChar).lowercased()
        guard let row = Int(rest.dropLast()) else { return nil }
        return canonicalPosition(row: row, column: col)
    }
}
