import SwiftUI

struct BudgetLimitView: View {
    @State private var limit = 0

    var body: some View {
        Form {
            AmountTextField("Limit", cents: $limit, entry: .required)
        }
    }
}
