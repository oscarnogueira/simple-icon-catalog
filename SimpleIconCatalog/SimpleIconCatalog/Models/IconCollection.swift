import Foundation
import SwiftUI

struct IconCollection: Identifiable, Hashable {
    let id: UUID
    var name: String
    var symbol: String      // SF Symbol name
    var colorHex: String    // persisted as hex, e.g. "#FF5733"
    var sortOrder: Int

    init(id: UUID = UUID(), name: String, symbol: String, colorHex: String, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }

    var color: Color { Color(hex: colorHex) }
}
