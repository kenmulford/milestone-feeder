import SwiftUI

struct SavingsGoalView: View {
    @State private var goal: Int?

    var body: some View {
        Form {
            AmountTextField("Goal", cents: $goal, entry: .optional, prompt: Text("0.00"))
        }
    }
}
