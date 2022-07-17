//
//  Middleware.swift
//  UnidirectionalFlow
//
//  Created by Majid Jabrayilov on 23.06.22.
//
public protocol Middleware<State, Action, Dependencies> {
    associatedtype State
    associatedtype Action
    associatedtype Dependencies
    
    func process(
        state: State,
        with action: Action,
        using dependencies: Dependencies
    ) async -> Action?
}

struct OptionalMiddleware<UnwrappedState, Action, Dependencies>: Middleware {
    typealias State = Optional<UnwrappedState>
    
    let middleware: any Middleware<UnwrappedState, Action, Dependencies>
    
    func process(state: State, with action: Action, using dependencies: Dependencies) async -> Action? {
        guard let state else {
            return nil
        }
        return await middleware.process(state: state, with: action, using: dependencies)
    }
}

struct LiftedMiddleware<
    LiftedState,LiftedAction, LiftedDependencies,
    LoweredState, LoweredAction, LoweredDependencies>: Middleware {
    
    let middleware: any Middleware<LoweredState, LoweredAction, LoweredDependencies>
    let keyPath: WritableKeyPath<LiftedState, LoweredState>
    let prism: Prism<LiftedAction, LoweredAction>
    let extractDependencies: (LiftedDependencies) -> LoweredDependencies
    
    func process(
        state: LiftedState,
        with action: LiftedAction,
        using dependencies: LiftedDependencies
    ) async -> LiftedAction? {
        guard let action = prism.extract(action) else {
            return nil
        }
        
        guard let action = await middleware.process(
            state: state[keyPath: keyPath],
            with: action,
            using: extractDependencies(dependencies)
        )
        else {
            return nil
        }
        
        return prism.embed(action)
    }
}

struct KeyedMiddleware<
    KeyedState, KeyedAction, KeyedDependencies,
    State, Action, Dependencies, Key: Hashable>: Middleware {
    
    let middleware: any Middleware<State, Action, Dependencies>
    let keyPath: WritableKeyPath<KeyedState, [Key: State]>
    let prism: Prism<KeyedAction, (Key, Action)>
    let extractDependencies: (KeyedDependencies) -> Dependencies
    
    func process(
        state: KeyedState,
        with action: KeyedAction,
        using dependencies: KeyedDependencies
    ) async -> KeyedAction? {
        guard
            let (key, action) = prism.extract(action),
            let state = state[keyPath: keyPath][key]
        else {
            return nil
        }
        
        let dependencies = extractDependencies(dependencies)
        
        guard let nextAction = await middleware.process(
            state: state,
            with: action,
            using: dependencies
        ) else {
            return nil
        }
        
        return prism.embed((key, nextAction))
    }
}

struct OffsetMiddleware<
    IndexedState, IndexedAction, IndexedDependencies,
    State, Action, Dependencies>: Middleware {
    
    let middleware: any Middleware<State, Action, Dependencies>
    
    let keyPath: WritableKeyPath<IndexedState, [State]>
    let prism: Prism<IndexedAction, (Int, Action)>
    let extractDependencies: (IndexedDependencies) -> Dependencies
    
    func process(
        state: IndexedState,
        with action: IndexedAction,
        using dependencies: IndexedDependencies
    ) async -> IndexedAction? {
        guard let (index, action) = prism.extract(action) else {
            return nil
        }
        
        let state = state[keyPath: keyPath][index]
        let dependencies = extractDependencies(dependencies)
        
        guard let nextAction = await middleware.process(
            state: state,
            with: action,
            using: dependencies
        ) else {
            return nil
        }
        
        return prism.embed((index, nextAction))
    }
}

struct SendableMiddleware<State, Action, Dependencies>: Middleware {
    let closure: @Sendable (State, Action, Dependencies) async -> Action?
    
    func process(state: State, with action: Action, using dependencies: Dependencies) async -> Action? {
        await closure(state, action, dependencies)
    }
}

extension Middleware {
    public func optional() -> some Middleware<State?, Action, Dependencies> {
        OptionalMiddleware(middleware: self)
    }
    
    public func lifted<LiftedState, LiftedAction, LiftedDependencies>(
        keyPath: WritableKeyPath<LiftedState, State>,
        prism: Prism<LiftedAction, Action>,
        extractDependencies: @escaping (LiftedDependencies) -> Dependencies
    ) -> some Middleware<LiftedState, LiftedAction, LiftedDependencies> {
        LiftedMiddleware(middleware: self, keyPath: keyPath, prism: prism, extractDependencies: extractDependencies)
    }
    
    public func offset<IndexedState, IndexedAction, IndexedDependencies>(
        keyPath: WritableKeyPath<IndexedState, [State]>,
        prism: Prism<IndexedAction, (Int, Action)>,
        extractDependencies: @escaping (IndexedDependencies) -> Dependencies
    ) -> some Middleware<IndexedState, IndexedAction, IndexedDependencies> {
        OffsetMiddleware(middleware: self, keyPath: keyPath, prism: prism, extractDependencies: extractDependencies)
    }
    
    public func keyed<KeyedState, KeyedAction, KeyedDependencies, Key: Hashable>(
        keyPath: WritableKeyPath<KeyedState, [Key: State]>,
        prism: Prism<KeyedAction, (Key, Action)>,
        extractDependencies: @escaping (KeyedDependencies) -> Dependencies
    ) -> some Middleware<KeyedState, KeyedAction, KeyedDependencies> {
        KeyedMiddleware(middleware: self, keyPath: keyPath, prism: prism, extractDependencies: extractDependencies)
    }
}
