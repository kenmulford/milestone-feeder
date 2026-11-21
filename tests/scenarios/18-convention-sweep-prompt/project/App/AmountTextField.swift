import SwiftUI

struct AmountTextField: View {
    enum Entry { case required, optional }

    private let title: String
    private let entry: Entry
    private let requiredCents: Binding<Int>?
    private let optionalCents: Binding<Int?>?
    private let prompt: Text?

    init(_ title: String, cents: Binding<Int>, entry: Entry) {
        self.title = title
        self.entry = entry
        self.requiredCents = cents
        self.optionalCents = nil
        self.prompt = nil
    }

    init(_ title: String, cents: Binding<Int?>, entry: Entry, prompt: Text) {
        self.title = title
        self.entry = entry
        self.requiredCents = nil
        self.optionalCents = cents
        self.prompt = prompt
    }

    var body: some View {
        switch entry {
        case .required:
            TextField(title, value: requiredCents!, format: .number.precision(.fractionLength(2)))
        case .optional:
            TextField(title, value: optionalCents!, format: .number.precision(.fractionLength(2)), prompt: prompt)
        }
    }
}
