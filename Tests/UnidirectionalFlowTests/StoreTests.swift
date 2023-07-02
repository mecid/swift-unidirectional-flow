//
//  StoreTests.swift
//  UnidirectionalFlowTests
//
//  Created by Majid Jabrayilov on 23.06.22.
//
@testable import UnidirectionalFlow
import Combine
import XCTest

@MainActor final class StoreTests: XCTestCase {
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
            return .increment
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
    
    func testSend() async {
        let store = Store<State, Action>(
            initialState: .init(),
            reducer: TestReducer(),
            middlewares: [TestMiddleware()],
            publishers: []
        )
        
        XCTAssertEqual(store.counter, 0)
        await store.send(.increment)
        XCTAssertEqual(store.counter, 1)
        await store.send(.decrement)
        XCTAssertEqual(store.counter, 0)
    }
    
    func testMiddleware() async {
        let store = Store<State, Action>(
            initialState: .init(),
            reducer: TestReducer(),
            middlewares: [TestMiddleware()],
            publishers: []
        )
        
        XCTAssertEqual(store.counter, 0)
        let task = Task { await store.send(.sideEffect) }
        XCTAssertEqual(store.counter, 0)
        await task.value
        XCTAssertEqual(store.counter, 1)
    }
    
    func testMiddlewareCancellation() async {
        let store = Store<State, Action>(
            initialState: .init(),
            reducer: TestReducer(),
            middlewares: [TestMiddleware()],
            publishers: []
        )
        
        XCTAssertEqual(store.counter, 0)
        let task = Task { await store.send(.sideEffect) }
        XCTAssertEqual(store.counter, 0)
        task.cancel()
        await task.value
        XCTAssertEqual(store.counter, 0)
    }
    
    func testDerivedStore() async throws {
        let publisher1 = PassthroughSubject<Action, Never>()
        let publisher2 = PassthroughSubject<Action, Never>()

        let store = Store<State, Action>(
            initialState: .init(),
            reducer: TestReducer(),
            middlewares: [TestMiddleware()],
            publishers: [
                publisher1.eraseToAnyPublisher(),
                publisher2.eraseToAnyPublisher()
            ]
        )
        
        let derived = store.derived(deriveState: { $0 }, deriveAction: { $0 } )
        
        XCTAssertEqual(store.counter, 0)
        XCTAssertEqual(derived.counter, 0)
        
        await store.send(.sideEffect)
        
        XCTAssertEqual(store.counter, 1)
        XCTAssertEqual(derived.counter, 1)
        
        await derived.send(.sideEffect)
        
        XCTAssertEqual(store.counter, 2)
        XCTAssertEqual(derived.counter, 2)
        
        let derivedTask = Task { await derived.send(.sideEffect) }
        derivedTask.cancel()
        await derivedTask.value
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        XCTAssertEqual(store.counter, 2)
        XCTAssertEqual(derived.counter, 2)
        
        let task = Task { await store.send(.sideEffect) }
        task.cancel()
        await task.value
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        XCTAssertEqual(store.counter, 2)
        XCTAssertEqual(derived.counter, 2)
        
        await store.send(.increment)
        
        XCTAssertEqual(store.counter, 3)
        XCTAssertEqual(derived.counter, 3)

        await derived.send(.decrement)
        
        XCTAssertEqual(store.counter, 2)
        XCTAssertEqual(derived.counter, 2)

        publisher1.send(.increment)

        try await Task.sleep(nanoseconds: 1_000_000_000)

        XCTAssertEqual(store.counter, 3)
        XCTAssertEqual(derived.counter, 3)

        publisher2.send(.increment)

        try await Task.sleep(nanoseconds: 1_000_000_000)

        XCTAssertEqual(store.counter, 4)
        XCTAssertEqual(derived.counter, 4)
    }
    
    func testBinding() async {
        let store = Store<State, Action>(
            initialState: .init(),
            reducer: TestReducer(),
            middlewares: [TestMiddleware()],
            publishers: []
        )
        
        let binding = store.binding(
            extract: \.counter,
            embed: Action.set
        )
        
        binding.wrappedValue = 10
        
        await MainActor.run {
            XCTAssertEqual(store.counter, 10)
        }
    }
}
