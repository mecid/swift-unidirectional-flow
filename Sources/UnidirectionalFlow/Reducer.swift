//
//  Reducer.swift
//  UnidirectionalFlow
//
//  Created by Majid Jabrayilov on 23.06.22.
//
import Foundation

public protocol Reducer<State, Action> {
    associatedtype State
    associatedtype Action
    
    func reduce(oldState: State, with action: Action) -> State
}

struct IdentityReducer<State, Action>: Reducer {
    func reduce(oldState: State, with action: Action) -> State {
        oldState
    }
}

struct LiftedReducer<LiftedState, LiftedAction, LoweredState, LoweredAction>: Reducer {
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

struct OptionalReducer<UnwrappedState, Action>: Reducer {
    typealias State = Optional<UnwrappedState>
    
    let reducer: any Reducer<UnwrappedState, Action>
    
    func reduce(oldState: State, with action: Action) -> State {
        oldState.map { reducer.reduce(oldState: $0, with: action) } ?? oldState
    }
}

struct CombinedReducer<State, Action>: Reducer {
    let reducers: any Collection<any Reducer<State, Action>>
    
    func reduce(oldState: State, with action: Action) -> State {
        reducers.reduce(oldState) {
            $1.reduce(oldState: $0, with: action)
        }
    }
}

struct KeyedReducer<KeyedState, KeyedAction, State, Action, Key: Hashable>: Reducer {
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

struct OffsetReducer<IndexedState, IndexedAction, State, Action>: Reducer {
    let reducer: any Reducer<State, Action>
    
    let keyPath: WritableKeyPath<IndexedState, [State]>
    let prism: Prism<IndexedAction, (Int, Action)>
    
    func reduce(oldState: IndexedState, with action: IndexedAction) -> IndexedState {
        guard let (index, action) = prism.extract(action) else {
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
    public func lift<LiftedState, LiftedAction>(
        keyPath: WritableKeyPath<LiftedState, State>,
        prism: Prism<LiftedAction, Action>
    ) -> some Reducer<LiftedState, LiftedAction> {
        LiftedReducer(reducer: self, keyPath: keyPath, prism: prism)
    }
    
    public func keyed<KeyedState, KeyedAction, Key: Hashable>(
        keyPath: WritableKeyPath<KeyedState, [Key: State]>,
        prism: Prism<KeyedAction, (Key, Action)>
    ) -> some Reducer<KeyedState, KeyedAction> {
        KeyedReducer(reducer: self, keyPath: keyPath, prism: prism)
    }
    
    public func offset<OffsetState, OffsetAction>(
        keyPath: WritableKeyPath<OffsetState, [State]>,
        prism: Prism<OffsetAction, (Int, Action)>
    ) -> some Reducer<OffsetState, OffsetAction> {
        OffsetReducer(reducer: self, keyPath: keyPath, prism: prism)
    }
    
    public func optional() -> some Reducer<State?, Action> {
        OptionalReducer(reducer: self)
    }
    
    public static func identity() -> some Reducer<State, Action> {
        IdentityReducer<State, Action>()
    }
    
    public static func combine(
        reducers: any Collection<any Reducer<State, Action>>
    ) -> some Reducer<State, Action> {
        CombinedReducer(reducers: reducers)
    }
}
