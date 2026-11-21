import SwiftUI

struct AccountsView: View {
    @State private var width: CGFloat = 0

    var body: some View {
        Group {
            if width >= 700 {
                Table(rows) {
                    TableColumn("Name", value: \.name)
                    TableColumn("Amount", value: \.amount)
                }
            } else {
                List(rows) { row in
                    Text(row.name)
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            width = newWidth
        }
    }

    private let rows: [Row] = []

    struct Row: Identifiable {
        let id = UUID()
        let name: String
        let amount: String
    }
}
