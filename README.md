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

struct SearchMiddleware: Middleware {
    struct Dependencies {
        var search: (String) async throws -> SearchResponse
        
        static var production: Dependencies {
            .init { query in
                guard var urlComponents = URLComponents(string: "https://api.github.com/search/repositories") else {
                    return .init(items: [])
                }
                urlComponents.queryItems = [.init(name: "q", value: query)]
                
                guard let url = urlComponents.url else {
                    return .init(items: [])
                }
                
                let (data, _) = try await URLSession.shared.data(from: url)
                return try JSONDecoder().decode(SearchResponse.self, from: data)
            }
        }
    }

    let dependencies: Dependencies
    
    func process(state: SearchState, with action: SearchAction) async -> SearchAction? {
        switch action {
        case let .search(query):
            let results = try? await dependencies.search(query)
            guard !Task.isCancelled else {
                return .setResults(repos: state.repos)
            }
            return .setResults(repos: results?.items ?? [])
        default:
            return nil
        }
    }
}

typealias SearchStore = Store<SearchState, SearchAction>

struct SearchContainerView: View {
    @StateObject private var store = SearchStore(
        initialState: .init(),
        reducer: SearchReducer(),
        middlewares: [SearchMiddleware(dependencies: .production)]
    )
    @State private var query = ""
    
    var body: some View {
        List(store.repos) { repo in
            VStack(alignment: .leading) {
                Text(verbatim: repo.name)
                    .font(.headline)
                
                if let description = repo.description {
                    Text(verbatim: description)
                }
            }
        }
        .redacted(reason: store.isLoading ? .placeholder : [])
        .searchable(text: $query)
        .task(id: query) {
            await store.send(.search(query: query))
        }
        .navigationTitle("Github Search")
    }
}

```
To learn more about Unidirectional Flow in Swift, take a look at my dedicated [post](https://swiftwithmajid.com/2023/07/11/unidirectional-flow-in-swift/).

## Installation
Add this Swift package in Xcode using its Github repository url. (File > Swift Packages > Add Package Dependency...)

## Author
Majid Jabrayilov: cmecid@gmail.com

## License
swift-unidirectional-flow package is available under the MIT license. See the LICENSE file for more info.
