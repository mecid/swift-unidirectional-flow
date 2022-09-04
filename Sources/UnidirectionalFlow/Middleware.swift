//
//  Middleware.swift
//  UnidirectionalFlow
//
//  Created by Majid Jabrayilov on 23.06.22.
//

/// Protocol defining a way to intercept an action to return another one.
public protocol Middleware<State, Action> {
    associatedtype State
    associatedtype Action
    
    /// The method processing the current action and returning another one.
    func process(state: State, with action: Action) async -> Action?
}

struct OptionalMiddleware<UnwrappedState, Action>: Middleware {
    typealias State = Optional<UnwrappedState>
    
    let middleware: any Middleware<UnwrappedState, Action>
    
    func process(state: State, with action: Action) async -> Action? {
        guard let state else {
            return nil
        }
        return await middleware.process(state: state, with: action)
    }
}

struct LiftedMiddleware<LiftedState,LiftedAction, LoweredState, LoweredAction>: Middleware {
    let middleware: any Middleware<LoweredState, LoweredAction>
    let keyPath: WritableKeyPath<LiftedState, LoweredState>
    let prism: Prism<LiftedAction, LoweredAction>
    
    func process(state: LiftedState, with action: LiftedAction) async -> LiftedAction? {
        guard let action = prism.extract(action) else {
            return nil
        }
        
        guard let action = await middleware.process(state: state[keyPath: keyPath], with: action) else {
            return nil
        }
        
        return prism.embed(action)
    }
}

struct KeyedMiddleware<KeyedState, KeyedAction, State, Action, Key: Hashable>: Middleware {
    let middleware: any Middleware<State, Action>
    let keyPath: WritableKeyPath<KeyedState, [Key: State]>
    let prism: Prism<KeyedAction, (Key, Action)>
    
    func process(state: KeyedState, with action: KeyedAction) async -> KeyedAction? {
        guard
            let (key, action) = prism.extract(action),
            let state = state[keyPath: keyPath][key]
        else {
            return nil
        }
        
        guard let nextAction = await middleware.process(state: state, with: action) else {
            return nil
        }
        
        return prism.embed((key, nextAction))
    }
}

struct OffsetMiddleware<IndexedState, IndexedAction, State, Action>: Middleware {
    let middleware: any Middleware<State, Action>
    let keyPath: WritableKeyPath<IndexedState, [State]>
    let prism: Prism<IndexedAction, (Int, Action)>
    
    func process(state: IndexedState, with action: IndexedAction) async -> IndexedAction? {
        guard let (index, action) = prism.extract(action) else {
            return nil
        }
        
        let state = state[keyPath: keyPath][index]
        
        guard let nextAction = await middleware.process(state: state, with: action) else {
            return nil
        }
        
        return prism.embed((index, nextAction))
    }
}

struct SendableMiddleware<State, Action>: Middleware {
    let closure: @Sendable (State, Action) async -> Action?
    
    func process(state: State, with action: Action) async -> Action? {
        await closure(state, action)
    }
}

extension Middleware {
    /// Transforms the `Middleware` to operate over `Optional<State>`.
    public func optional() -> some Middleware<State?, Action> {
        OptionalMiddleware(middleware: self)
    }
    
    /// Transforms the `Middleware` to operate over `State` wrapped into another type.
    public func lifted<LiftedState, LiftedAction>(
        keyPath: WritableKeyPath<LiftedState, State>,
        prism: Prism<LiftedAction, Action>
    ) -> some Middleware<LiftedState, LiftedAction> {
        LiftedMiddleware(middleware: self, keyPath: keyPath, prism: prism)
    }
    
    /// Transforms the `Middleware` to operate over `State` in an `Array`.
    public func offset<IndexedState, IndexedAction>(
        keyPath: WritableKeyPath<IndexedState, [State]>,
        prism: Prism<IndexedAction, (Int, Action)>
    ) -> some Middleware<IndexedState, IndexedAction> {
        OffsetMiddleware(middleware: self, keyPath: keyPath, prism: prism)
    }
    
    /// Transforms the `Middleware` to operate over `State` in a `Dictionary`.
    public func keyed<KeyedState, KeyedAction, Key: Hashable>(
        keyPath: WritableKeyPath<KeyedState, [Key: State]>,
        prism: Prism<KeyedAction, (Key, Action)>
    ) -> some Middleware<KeyedState, KeyedAction> {
        KeyedMiddleware(middleware: self, keyPath: keyPath, prism: prism)
    }
}
