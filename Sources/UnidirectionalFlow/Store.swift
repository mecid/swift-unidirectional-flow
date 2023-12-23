//
//  Store.swift
//  UnidirectionalFlow
//
//  Created by Majid Jabrayilov on 11.06.22.
//
import Observation

/// Type that stores the state of the app or feature.
@Observable @dynamicMemberLookup public final class Store<State, Action> {
    private var state: State

    private let reducer: any Reducer<State, Action>
    private let middlewares: any Collection<any Middleware<State, Action>>
    private let lock = NSRecursiveLock()

    /// Creates an instance of `Store` with the folowing parameters.
    public init(
        initialState state: State,
        reducer: some Reducer<State, Action>,
        middlewares: some Collection<any Middleware<State, Action>>
    ) {
        self.state = state
        self.reducer = reducer
        self.middlewares = middlewares
    }
    
    /// A subscript providing access to the state of the store.
    public subscript<T>(dynamicMember keyPath: KeyPath<State, T>) -> T {
        lock.withLock { state[keyPath: keyPath] }
    }
    
    /// Use this method to mutate the state of the store by feeding actions.
    public func send(_ action: Action) async {
        await apply(action)
        await intercept(action)
    }
    
    @MainActor private func apply(_ action: Action) {
        lock.withLock {
            state = reducer.reduce(oldState: state, with: action)
        }
    }
    
    private func intercept(_ action: Action) async {
        let capturedState = lock.withLock { state }
        
        await withTaskGroup(of: Optional<Action>.self) { group in
            middlewares.forEach { middleware in
                group.addTask {
                    await middleware.process(state: capturedState, with: action)
                }
            }
            
            for await case let nextAction? in group {
                await send(nextAction)
            }
        }
    }
}

extension Store {
    /// Use this method to create another `Store` deriving from the current one.
    @available(*, deprecated, message: "Use multiple stores instead of derived store")
    public func derived<DerivedState: Equatable, DerivedAction: Equatable>(
        deriveState: @escaping (State) -> DerivedState,
        deriveAction: @escaping (DerivedAction) -> Action
    ) -> Store<DerivedState, DerivedAction> {
        let derived = Store<DerivedState, DerivedAction>(
            initialState: lock.withLock { deriveState(state) },
            reducer: IdentityReducer(),
            middlewares: [
                ClosureMiddleware { _, action in
                    await self.send(deriveAction(action))
                    return nil
                }
            ]
        )
        
        @Sendable func enableStateObservationTracking() {
            withObservationTracking {
                let newState = lock.withLock { deriveState(state) }
                derived.lock.withLock {
                    if derived.state != newState {
                        derived.state = newState
                    }
                }
            } onChange: {
                Task {
                    enableStateObservationTracking()
                }
            }
        }
        
        enableStateObservationTracking()

        return derived
    }
}

import SwiftUI

extension Store {
    /// Use this method to create a `SwiftUI.Binding` from any instance of `Store`.
    public func binding<Value>(
        extract: @escaping (State) -> Value,
        embed: @escaping (Value) -> Action
    ) -> Binding<Value> {
        .init(
            get: { self.lock.withLock { extract(self.state) } },
            set: { newValue in
                let action = embed(newValue)
                
                MainActor.assumeIsolated {
                    self.apply(action)
                }
                
                Task {
                    await self.intercept(action)
                }
            }
        )
    }
}
