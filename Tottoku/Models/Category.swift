import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    var order: Int
    var colorName: String
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        order: Int,
        colorName: String = "indigo",
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.order = order
        self.colorName = colorName
        self.isArchived = isArchived
    }
}
