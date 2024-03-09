//
//  GithubApp.swift
//  Example
//
//  Created by Majid Jabrayilov on 17.07.22.
//
import SwiftUI
import UnidirectionalFlow

struct Repo: Identifiable, Equatable, Decodable {
    let id: Int
    let name: String
    let description: String?
}

struct SearchResponse: Decodable {
    let items: [Repo]
}

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

actor SearchMiddleware: Middleware {
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
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
    
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

@MainActor struct SearchView: View {
    @State private var store = SearchStore(
        initialState: .init(),
        reducer: SearchReducer(),
        middlewares: [SearchMiddleware(dependencies: .production)]
    )
    @State private var query = ""
    
    var body: some View {
        List(store.repos) { repo in
            VStack(alignment: .leading) {
                Text(repo.name)
                    .font(.headline)
                
                if let description = repo.description {
                    Text(description)
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

@main struct GithubApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                SearchView()
            }
        }
    }
}
