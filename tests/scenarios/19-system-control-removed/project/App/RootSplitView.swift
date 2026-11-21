import SwiftUI

struct RootSplitView: View {
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView()
                .toolbar(removing: .sidebarToggle)
        } detail: {
            DetailView()
        }
    }
}

struct SidebarView: View {
    var body: some View {
        List {
            Text("Accounts")
            Text("Budgets")
            Text("Reports")
        }
    }
}

struct DetailView: View {
    var body: some View {
        Text("Select an item")
    }
}
