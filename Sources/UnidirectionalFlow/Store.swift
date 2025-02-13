//
//  Store.swift
//  UnidirectionalFlow
//
//  Created by Majid Jabrayilov on 11.06.22.
//
import Observation

/// Type that stores the state of the app or module allowing feeding actions.
@Observable @dynamicMemberLookup @MainActor public final class Store<State: Sendable, Action: Sendable> {
    private var state: State
    private let reducer: any Reducer<State, Action>
    private let middlewares: any Collection<any Middleware<State, Action>>

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
        state[keyPath: keyPath]
    }
    
    /// Use this method to mutate the state of the store by feeding actions.
    public func send(_ action: Action) async {
        apply(action)
        await intercept(action)
    }
    
    private func apply(_ action: Action) {
        state = reducer.reduce(oldState: state, with: action)
    }
    
    private func intercept(_ action: Action) async {
        await withDiscardingTaskGroup { group in
            for middleware in middlewares {
                group.addTask {
                    if let nextAction = await middleware.process(state: self.state, with: action) {
                        await self.send(nextAction)
                    }
                }
            }
        }
    }
}

extension Store {
    /// Use this method to create another `Store` deriving from the current one.
    @available(*, deprecated, message: "Use multiple stores instead of derived store")
    public func derived<DerivedState: Equatable, DerivedAction: Equatable>(
        deriveState: @Sendable @escaping (State) -> DerivedState,
        deriveAction: @Sendable @escaping (DerivedAction) -> Action
    ) -> Store<DerivedState, DerivedAction> {
        let store = Store<DerivedState, DerivedAction>(
            initialState: deriveState(state),
            reducer: IdentityReducer(),
            middlewares: [
                ClosureMiddleware { _, action in
                    await self.send(deriveAction(action))
                    return nil
                }
            ]
        )
        
        enableStateObservation(for: store, deriveState: deriveState)

        return store
    }
    
    private func enableStateObservation<DerivedState: Equatable, DerivedAction: Equatable>(
        for store: Store<DerivedState, DerivedAction>,
        deriveState: @Sendable @escaping (State) -> DerivedState
    ) {
        withObservationTracking {
            let newState = deriveState(state)
            if store.state != newState {
                store.state = newState
            }
        } onChange: {
            Task {
                await self.enableStateObservation(for: store, deriveState: deriveState)
            }
        }
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
            get: { extract(self.state) },
            set: { newValue in
                let action = embed(newValue)
                
                self.apply(action)
                
                Task {
                    await self.intercept(action)
                }
            }
        )
    }
}
