import SwiftUI

struct TransferView: View {
    @State private var amount = 0

    var body: some View {
        Form {
            AmountTextField("Transfer", cents: $amount, entry: .required)
        }
    }
}
