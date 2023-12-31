//
//  StoreTests.swift
//  UnidirectionalFlowTests
//
//  Created by Majid Jabrayilov on 23.06.22.
//
@testable import UnidirectionalFlow
import XCTest

final class StoreTests: XCTestCase {
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
    
    func testSend() async {
        let store = Store<State, Action>(
            initialState: .init(),
            reducer: TestReducer(),
            middlewares: [TestMiddleware()]
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
            middlewares: [TestMiddleware()]
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
            middlewares: [TestMiddleware()]
        )
        
        XCTAssertEqual(store.counter, 0)
        let task = Task { await store.send(.sideEffect) }
        try? await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertEqual(store.counter, 0)
        task.cancel()
        await task.value
        XCTAssertEqual(store.counter, 0)
    }
    
    func testDerivedStore() async throws {
        let store = Store<State, Action>(
            initialState: .init(),
            reducer: TestReducer(),
            middlewares: [TestMiddleware()]
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
    }
    
    @MainActor func testBinding() async {
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
        XCTAssertEqual(store.counter, 10)
    }
    
    func testThreadSafety() {
        measure {
            let store = Store<State, Action>(
                initialState: .init(),
                reducer: TestReducer(),
                middlewares: [TestMiddleware()]
            )
            
            let expectation = expectation(description: "measurement")
            
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for _ in 1...1_000_000 {
                        group.addTask {
                            await store.send(.increment)
                        }
                    }
                    
                    await group.waitForAll()
                    expectation.fulfill()
                }
            }
         
            wait(for: [expectation], timeout: 200)
            
            XCTAssertEqual(store.counter, 1_000_000)
        }
    }
}
