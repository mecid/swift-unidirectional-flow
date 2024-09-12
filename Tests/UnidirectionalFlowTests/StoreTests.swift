//
//  StoreTests.swift
//  UnidirectionalFlowTests
//
//  Created by Majid Jabrayilov on 23.06.22.
//
@testable import UnidirectionalFlow
import Testing

@MainActor struct StoreTests {
    struct State: Equatable {
        var counter = 0
    }
    
    enum Action: Equatable {
        case increment
        case decrement
        case sideEffect
        case set(Int)
    }
    
    struct TestMiddleware: Middleware {
        func process(state: State, with action: Action) async -> Action? {
            guard action == .sideEffect else {
                return nil
            }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return Task.isCancelled ? nil : .increment
        }
    }
    
    struct TestReducer: Reducer {
        func reduce(oldState: State, with action: Action) -> State {
            var state = oldState
            switch action {
            case .increment:
                state.counter += 1
            case .decrement:
                state.counter -= 1
            case let .set(value):
                state.counter = value
            default:
                break
            }
            return state
        }
    }
    
    @Test func send() async {
        let store = Store<State, Action>(
            initialState: .init(),
            reducer: TestReducer(),
            middlewares: [TestMiddleware()]
        )
        
        #expect(store.counter == 0)
        await store.send(.increment)
        #expect(store.counter == 1)
        await store.send(.decrement)
        #expect(store.counter == 0)
    }
    
    @Test func middleware() async {
        let store = Store<State, Action>(
            initialState: .init(),
            reducer: TestReducer(),
            middlewares: [TestMiddleware()]
        )
        
        #expect(store.counter == 0)
        let task = Task { await store.send(.sideEffect) }
        #expect(store.counter == 0)
        await task.value
        #expect(store.counter == 1)
    }
    
    @Test func middlewareCancellation() async {
        let store = Store<State, Action>(
            initialState: .init(),
            reducer: TestReducer(),
            middlewares: [TestMiddleware()]
        )
        
        #expect(store.counter == 0)
        let task = Task { await store.send(.sideEffect) }
        try? await Task.sleep(nanoseconds: 10_000_000)
        #expect(store.counter == 0)
        task.cancel()
        await task.value
        #expect(store.counter == 0)
    }
    
    @Test func derivedStore() async throws {
        let store = Store<State, Action>(
            initialState: .init(),
            reducer: TestReducer(),
            middlewares: [TestMiddleware()]
        )
        
        let derived = store.derived(deriveState: { $0 }, deriveAction: { $0 } )
        
        #expect(store.counter == 0)
        #expect(derived.counter == 0)
        
        await store.send(.sideEffect)
        
        #expect(store.counter == 1)
        #expect(derived.counter == 1)
        
        await derived.send(.sideEffect)
        
        #expect(store.counter == 2)
        #expect(derived.counter == 2)
        
        let derivedTask = Task { await derived.send(.sideEffect) }
        derivedTask.cancel()
        await derivedTask.value
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        #expect(store.counter == 2)
        #expect(derived.counter == 2)
        
        let task = Task { await store.send(.sideEffect) }
        task.cancel()
        await task.value
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        #expect(store.counter == 2)
        #expect(derived.counter == 2)
        
        await store.send(.increment)
        
        #expect(store.counter == 3)
        #expect(derived.counter == 3)
        
        await derived.send(.decrement)
        
        #expect(store.counter == 2)
        #expect(derived.counter == 2)
    }
    
    @Test func binding() async {
        let store = Store<State, Action>(
            initialState: .init(),
            reducer: TestReducer(),
            middlewares: [TestMiddleware()]
        )
        
        let binding = store.binding(
            extract: \.counter,
            embed: Action.set
        )
        
        binding.wrappedValue = 10
        
        try? await Task.sleep(nanoseconds: 1_000_000)
        #expect(store.counter == 10)
    }
    
    @Test func threadSafety() async {
        let store = Store<State, Action>(
            initialState: .init(),
            reducer: TestReducer(),
            middlewares: [TestMiddleware()]
        )
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 1...100_000 {
                group.addTask {
                    await store.send(.increment)
                }
            }
            
            await group.waitForAll()
        }
        
        #expect(store.counter == 100_000)
    }
}
