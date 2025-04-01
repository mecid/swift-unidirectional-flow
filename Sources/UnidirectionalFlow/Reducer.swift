//
//  Reducer.swift
//  UnidirectionalFlow
//
//  Created by Majid Jabrayilov on 23.06.22.
//
import Foundation

/// A protocol that defines how state mutations occur in response to actions.
///
/// Reducers are pure functions that produce a new state by applying an action to the current state.
/// They form the core of state mutation logic in a unidirectional data flow architecture.
public protocol Reducer<State, Action> {
    associatedtype State
    associatedtype Action
    
    /// The function returning a new state by taking an old state and an action.
    func reduce(oldState: State, with action: Action) -> State
}

/// A type conforming to the ``Reducer`` protocol that doesn't apply any mutation to the old state.
public struct IdentityReducer<State, Action>: Reducer {
    public func reduce(oldState: State, with action: Action) -> State {
        oldState
    }
}

/// The type of ``Reducer`` combining a `Collection` of reducers into one instance.
public struct CombinedReducer<State, Action>: Reducer {
    let reducers: any Collection<any Reducer<State, Action>>
    
    public init(reducers: any Reducer<State, Action>...) {
        self.reducers = reducers
    }
    
    public init(reducers: some Collection<any Reducer<State, Action>>) {
        self.reducers = reducers
    }
    
    public func reduce(oldState: State, with action: Action) -> State {
        reducers.reduce(oldState) {
            $1.reduce(oldState: $0, with: action)
        }
    }
}

private struct LiftedReducer<LiftedState, LiftedAction, LoweredState, LoweredAction>: Reducer {
    typealias State = LiftedState
    typealias Action = LiftedAction
    
    let reducer: any Reducer<LoweredState, LoweredAction>
    let keyPath: WritableKeyPath<LiftedState, LoweredState>
    let prism: Prism<LiftedAction, LoweredAction>
    
    func reduce(oldState: State, with action: Action) -> State {
        guard let loweredAction = prism.extract(action) else {
            return oldState
        }
        
        var oldState = oldState
        
        oldState[keyPath: keyPath] = reducer.reduce(
            oldState: oldState[keyPath: keyPath],
            with: loweredAction
        )
        
        return oldState
    }
}

private struct OptionalReducer<UnwrappedState, Action>: Reducer {
    typealias State = Optional<UnwrappedState>
    
    let reducer: any Reducer<UnwrappedState, Action>
    
    func reduce(oldState: State, with action: Action) -> State {
        oldState.map { reducer.reduce(oldState: $0, with: action) } ?? oldState
    }
}

private struct KeyedReducer<KeyedState, KeyedAction, State, Action, Key: Hashable>: Reducer {
    let reducer: any Reducer<State, Action>
    
    let keyPath: WritableKeyPath<KeyedState, [Key: State]>
    let prism: Prism<KeyedAction, (Key, Action)>
    
    func reduce(oldState: KeyedState, with action: KeyedAction) -> KeyedState {
        var oldState = oldState
        
        guard
            let (key, action) = prism.extract(action),
            let state = oldState[keyPath: keyPath][key]
        else {
            return oldState
        }
        
        let newState = reducer.reduce(oldState: state, with: action)
        oldState[keyPath: keyPath][key] = newState
        
        return oldState
    }
}

private struct OffsetReducer<IndexedState, IndexedAction, State, Action>: Reducer {
    let reducer: any Reducer<State, Action>
    
    let keyPath: WritableKeyPath<IndexedState, [State]>
    let prism: Prism<IndexedAction, (Int, Action)>
    
    func reduce(oldState: IndexedState, with action: IndexedAction) -> IndexedState {
        guard
            let (index, action) = prism.extract(action),
            oldState[keyPath: keyPath].indices.contains(index)
        else {
            return oldState
        }
        
        var oldState = oldState
        let newState = reducer.reduce(
            oldState: oldState[keyPath: keyPath][index],
            with: action
        )
        oldState[keyPath: keyPath][index] = newState
        return oldState
    }
}

extension Reducer {
    /// Transforms the reducer to operate over `State` wrapped into another type.
    public func lifted<LiftedState, LiftedAction>(
        keyPath: WritableKeyPath<LiftedState, State>,
        prism: Prism<LiftedAction, Action>
    ) -> some Reducer<LiftedState, LiftedAction> {
        LiftedReducer(reducer: self, keyPath: keyPath, prism: prism)
    }
    
    /// Transforms the reducer to operate over `State` in a `Dictionary`.
    public func keyed<KeyedState, KeyedAction, Key: Hashable>(
        keyPath: WritableKeyPath<KeyedState, [Key: State]>,
        prism: Prism<KeyedAction, (Key, Action)>
    ) -> some Reducer<KeyedState, KeyedAction> {
        KeyedReducer(reducer: self, keyPath: keyPath, prism: prism)
    }
    
    /// Transforms the reducer to operate over `State``State` in an `Array`.
    public func offset<OffsetState, OffsetAction>(
        keyPath: WritableKeyPath<OffsetState, [State]>,
        prism: Prism<OffsetAction, (Int, Action)>
    ) -> some Reducer<OffsetState, OffsetAction> {
        OffsetReducer(reducer: self, keyPath: keyPath, prism: prism)
    }
    
    /// Transforms the reducer to operate over `Optional<State>`.
    public func optional() -> some Reducer<State?, Action> {
        OptionalReducer(reducer: self)
    }
}
