//
//  StoreTests.swift
//  UnidirectionalFlowTests
//
//  Created by Majid Jabrayilov on 23.06.22.
//
@testable import UnidirectionalFlow
import XCTest

@MainActor final class StoreTests: XCTestCase {
    struct State: Equatable {
        var counter = 0
    }
    
    enum Action: Equatable {
        case increment
        case decrement
        case sideEffect
    }
    
    struct TestMiddleware: Middleware {
        func process(state: State, with action: Action, using dependencies: Void) async -> Action? {
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
            default:
                break
            }
            return state
        }
    }
    
    func testSend() async {
        let system = Store<State, Action, Void>(
            initialState: .init(),
            reducer: TestReducer(),
            dependencies: (),
            middlewares: [TestMiddleware()]
        )
        
        XCTAssertEqual(system.state.counter, 0)
        await system.send(.increment)
        XCTAssertEqual(system.state.counter, 1)
        await system.send(.decrement)
        XCTAssertEqual(system.state.counter, 0)
    }
    
    func testSideEffects() async {
        let system = Store<State, Action, Void>(
            initialState: .init(),
            reducer: TestReducer(),
            dependencies: (),
            middlewares: [TestMiddleware()]
        )
        
        XCTAssertEqual(system.state.counter, 0)
        let task = Task { await system.send(.sideEffect) }
        XCTAssertEqual(system.state.counter, 0)
        await task.value
        XCTAssertEqual(system.state.counter, 1)
    }
    
    func testSideEffectCancellation() async {
        let system = Store<State, Action, Void>(
            initialState: .init(),
            reducer: TestReducer(),
            dependencies: (),
            middlewares: [TestMiddleware()]
        )
        
        XCTAssertEqual(system.state.counter, 0)
        let task = Task { await system.send(.sideEffect) }
        XCTAssertEqual(system.state.counter, 0)
        task.cancel()
        await task.value
        XCTAssertEqual(system.state.counter, 0)
    }
    
    func testDerivedSystem() async throws {
        let system = Store<State, Action, Void>(
            initialState: .init(),
            reducer: TestReducer(),
            dependencies: (),
            middlewares: [TestMiddleware()]
        )
        
        let derived = system.derived(deriveState: { $0 }, deriveAction: { $0 } )
        
        XCTAssertEqual(system.state.counter, 0)
        XCTAssertEqual(derived.state.counter, 0)
        
        await system.send(.sideEffect)
        
        XCTAssertEqual(system.state.counter, 1)
        XCTAssertEqual(derived.state.counter, 1)
        
        await derived.send(.sideEffect)
        
        XCTAssertEqual(system.state.counter, 2)
        XCTAssertEqual(derived.state.counter, 2)
        
        let derivedTask = Task { await derived.send(.sideEffect) }
        derivedTask.cancel()
        await derivedTask.value
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        XCTAssertEqual(system.state.counter, 2)
        XCTAssertEqual(derived.state.counter, 2)
        
        let task = Task { await system.send(.sideEffect) }
        task.cancel()
        await task.value
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        XCTAssertEqual(system.state.counter, 2)
        XCTAssertEqual(derived.state.counter, 2)
        
        await system.send(.increment)
        
        XCTAssertEqual(system.state.counter, 3)
        XCTAssertEqual(derived.state.counter, 3)
        
        await derived.send(.decrement)
        
        XCTAssertEqual(system.state.counter, 2)
        XCTAssertEqual(derived.state.counter, 2)
    }
}
