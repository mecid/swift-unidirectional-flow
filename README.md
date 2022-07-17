# swift-unidirectional-flow

Unidirectional flow implemented using the latest Swift Generics and Swift Concurrency features.

```swift
struct SearchState: Equatable {
    var repos: [Repo] = []
    var isLoading = false
}

enum SearchAction: Equatable {
    case search(query: String)
    case setResults(repos: [Repo])
}

struct SearchReducer: Reducer {
    func reduce(oldState: SearchState, with action: SearchAction) -> SearchState {
        var state = oldState
        
        switch action {
        case .search:
            state.isLoading = true
        case let .setResults(repos):
            state.repos = repos
            state.isLoading = false
        }
        
        return state
    }
}

struct SearchDependencies {
    var search: (String) async throws -> SearchResponse
}

struct SearchMiddleware: Middleware {
    func process(
        state: SearchState,
        with action: SearchAction,
        using dependencies: SearchDependencies
    ) async -> SearchAction? {
        switch action {
        case let .search(query):
            let results = try? await dependencies.search(query)
            return .setResults(repos: results?.items ?? [])
        default:
            return nil
        }
    }
}

typealias SearchStore = Store<SearchState, SearchAction, SearchDependencies>

struct SearchContainerView: View {
    @StateObject private var store = SearchStore(
        initialState: .init(),
        reducer: SearchReducer(),
        dependencies: .production,
        middlewares: [SearchMiddleware()]
    )
    @State private var query = ""
    
    var body: some View {
        List(store.state.repos) { repo in
            VStack(alignment: .leading) {
                Text(repo.name)
                    .font(.headline)
                
                if let description = repo.description {
                    Text(description)
                }
            }
        }
        .redacted(reason: store.state.isLoading ? .placeholder : [])
        .searchable(text: $query)
        .task(id: query) {
            await store.send(.search(query: query))
        }
        .navigationTitle("Github Search")
    }
}
```
