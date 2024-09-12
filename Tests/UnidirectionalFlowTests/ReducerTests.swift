//
//  ReducerTests.swift
//  UnidirectionalFlowTests
//
//  Created by Majid Jabrayilov on 23.06.22.
//
@testable import UnidirectionalFlow
import Testing

struct ReducerTests {
    struct State: Equatable {
        var counter: Int
    }
    
    enum Action: Equatable {
        case increment
        case decrement
    }
    
    struct CounterReducer: Reducer {
        func reduce(oldState: State, with action: Action) -> State {
            var state = oldState
            
            switch action {
            case .increment: state.counter += 1
            case .decrement: state.counter -= 1
            }
            
            return state
        }
    }
    
    @Test func optional() {
        var state: State? = State(counter: 10)
        let reducer = CounterReducer()
        let optionalReducer = reducer.optional()
        let newState = optionalReducer.reduce(oldState: state, with: .increment)
        #expect(newState == State(counter: 11))
        
        state = nil
        let anotherNewState = optionalReducer.reduce(oldState: state, with: .decrement)
        #expect(anotherNewState == nil)
    }
    
    @Test func offset() {
        struct OffsetState: Equatable {
            var value: [State] = [.init(counter: 1), .init(counter: 2)]
        }
        
        enum OffsetAction: Equatable {
            case action(Int, Action)
            
            static var prism: Prism<OffsetAction, (Int, Action)> {
                .init(embed: OffsetAction.action) {
                    guard case let OffsetAction.action(offset, action) = $0 else {
                        return nil
                    }
                    
                    return (offset, action)
                }
            }
        }
        
        let offsetReducer = CounterReducer().offset(
            keyPath: \OffsetState.value,
            prism: OffsetAction.prism
        )
        
        var state = OffsetState()
        
        let newState = offsetReducer.reduce(oldState: state, with: .action(1, .increment))
        state.value[1].counter += 1
        #expect(newState == state)
        
        let anotherState = offsetReducer.reduce(oldState: state, with: .action(3, .increment))
        #expect(anotherState == state)
    }
    
    @Test func keyed() {
        struct KeyedState: Equatable {
            var value: [String: State] = ["one": .init(counter: 10)]
        }
        
        enum KeyedAction: Equatable {
            case action(String, Action)
            
            static var prism: Prism<KeyedAction, (String, Action)> {
                .init(embed: KeyedAction.action) {
                    guard case let KeyedAction.action(key, action) = $0 else {
                        return nil
                    }
                    return (key, action)
                }
            }
        }
        
        let keyedReducer = CounterReducer().keyed(
            keyPath: \KeyedState.value,
            prism: KeyedAction.prism
        )
        
        var state = KeyedState()
        let newState = keyedReducer.reduce(oldState: state, with: .action("one", .increment))
        state.value["one"]?.counter += 1
        #expect(newState == state)
        
        let anotherNewState = keyedReducer.reduce(oldState: state, with: .action("two", .increment))
        #expect(anotherNewState == state)
    }
    
    @Test func combined() {
        let combinedReducer: some Reducer<State, Action> = CombinedReducer(
            reducers: [
                CounterReducer(), CounterReducer()
            ]
        )
        
        let state = State(counter: 0)
        let newState = combinedReducer.reduce(oldState: state, with: .increment)
        
        #expect(newState == .init(counter: 2))
    }
    
    @Test func lift() {
        struct LiftedState: Equatable {
            var state: State
        }
        
        enum LiftedAction: Equatable {
            case action(Action)
            
            static var prism: Prism<LiftedAction, Action> {
                .init(embed: LiftedAction.action) {
                    guard case let LiftedAction.action(action) = $0 else {
                        return nil
                    }
                    return action
                }
            }
        }
        
        let liftedReducer = CounterReducer().lifted(
            keyPath: \LiftedState.state,
            prism: LiftedAction.prism
        )
        
        var state = LiftedState(state: .init(counter: 1))
        let newState = liftedReducer.reduce(oldState: state, with: .action(.increment))
        state.state.counter += 1
        #expect(newState == state)
    }
    
    @Test func identity() {
        let identityReducer: some Reducer<State, Action> = IdentityReducer()
        let state = State(counter: 1)
        let newState = identityReducer.reduce(oldState: state, with: .increment)
        #expect(state == newState)
    }
}
