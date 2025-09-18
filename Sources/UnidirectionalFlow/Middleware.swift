//
//  Middleware.swift
//  UnidirectionalFlow
//
//  Created by Majid Jabrayilov on 23.06.22.
//

/// A protocol that defines middleware for intercepting and processing actions in a unidirectional data flow architecture.
///
/// Middleware provides a way to observe actions flowing through the store and optionally transform them
/// or trigger side effects. It can be used for logging, analytics, API calls, async tasks, or any other side effects.
public protocol Middleware<State, Action>: Sendable {
    associatedtype State: Sendable
    associatedtype Action: Sendable
    
    /// The method processing the current action and returning another one.
    func process(state: State, with action: Action) async -> Action?
}

struct OptionalMiddleware<UnwrappedState: Sendable, Action: Sendable>: Middleware {
    typealias State = Optional<UnwrappedState>
    
    let middleware: any Middleware<UnwrappedState, Action>
    
    func process(state: State, with action: Action) async -> Action? {
        guard let state else {
            return nil
        }
        return await middleware.process(state: state, with: action)
    }
}

struct LiftedMiddleware<LiftedState: Sendable, LiftedAction: Sendable, LoweredState, LoweredAction>: Middleware {
    let middleware: any Middleware<LoweredState, LoweredAction>
    let keyPath: KeyPath<LiftedState, LoweredState> & Sendable
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

struct KeyedMiddleware<KeyedState: Sendable, KeyedAction: Sendable, State, Action, Key: Hashable>: Middleware {
    let middleware: any Middleware<State, Action>
    let keyPath: KeyPath<KeyedState, [Key: State]> & Sendable
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

struct OffsetMiddleware<IndexedState: Sendable, IndexedAction: Sendable, State, Action>: Middleware {
    let middleware: any Middleware<State, Action>
    let keyPath: KeyPath<IndexedState, [State]> & Sendable
    let prism: Prism<IndexedAction, (Int, Action)>
    
    func process(state: IndexedState, with action: IndexedAction) async -> IndexedAction? {
        guard
            let (index, action) = prism.extract(action),
            state[keyPath: keyPath].indices.contains(index)
        else {
            return nil
        }
        
        let state = state[keyPath: keyPath][index]
        
        guard let nextAction = await middleware.process(state: state, with: action) else {
            return nil
        }
        
        return prism.embed((index, nextAction))
    }
}

struct ClosureMiddleware<State: Sendable, Action: Sendable>: Middleware {
    let closure: @Sendable (State, Action) async -> Action?
    
    func process(state: State, with action: Action) async -> Action? {
        await closure(state, action)
    }
}

extension Middleware {
    /// Transforms the ``Middleware`` to operate over `Optional<State>`.
    public func optional() -> some Middleware<State?, Action> {
        OptionalMiddleware(middleware: self)
    }
    
    /// Transforms the ``Middleware`` to operate over `State` wrapped into another type.
    public func lifted<LiftedState: Sendable, LiftedAction: Sendable>(
        keyPath: KeyPath<LiftedState, State> & Sendable,
        prism: Prism<LiftedAction, Action>
    ) -> some Middleware<LiftedState, LiftedAction> {
        LiftedMiddleware(middleware: self, keyPath: keyPath, prism: prism)
    }
    
    /// Transforms the ``Middleware`` to operate over `State` in an `Array`.
    public func offset<IndexedState: Sendable, IndexedAction: Sendable>(
        keyPath: KeyPath<IndexedState, [State]> & Sendable,
        prism: Prism<IndexedAction, (Int, Action)>
    ) -> some Middleware<IndexedState, IndexedAction> {
        OffsetMiddleware(middleware: self, keyPath: keyPath, prism: prism)
    }
    
    /// Transforms the ``Middleware`` to operate over `State` in a `Dictionary`.
    public func keyed<KeyedState: Sendable, KeyedAction: Sendable, Key: Hashable>(
        keyPath: KeyPath<KeyedState, [Key: State]> & Sendable,
        prism: Prism<KeyedAction, (Key, Action)>
    ) -> some Middleware<KeyedState, KeyedAction> {
        KeyedMiddleware(middleware: self, keyPath: keyPath, prism: prism)
    }
}
