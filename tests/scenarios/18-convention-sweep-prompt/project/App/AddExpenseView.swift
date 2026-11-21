import SwiftUI

struct AddExpenseView: View {
    @State private var amount = 0

    var body: some View {
        Form {
            AmountTextField("Amount", cents: $amount, entry: .required)
        }
    }
}
