//
//  Store.swift
//  UnidirectionalFlow
//
//  Created by Majid Jabrayilov on 11.06.22.
//
import Foundation

/// Type that stores the state of the app or feature.
@MainActor public final class Store<State, Action, Dependencies>: ObservableObject {
    /// The current state of the store
    @Published public private(set) var state: State

    private let reducer: any Reducer<State, Action>
    private let dependencies: Dependencies
    private let middlewares: any Collection<any Middleware<State, Action, Dependencies>>

    /// Creates an instance of `Store` with the folowing parameters.
    public init(
        initialState state: State,
        reducer: some Reducer<State, Action>,
        dependencies: Dependencies,
        middlewares: some Collection<any Middleware<State, Action, Dependencies>>
    ) {
        self.state = state
        self.reducer = reducer
        self.dependencies = dependencies
        self.middlewares = middlewares
    }
    
    /// Use this method to mutate the state of the store by feeding actions.
    public func send(_ action: Action) async {
        state = reducer.reduce(oldState: state, with: action)

        await withTaskGroup(of: Optional<Action>.self) { [state, dependencies] group in
            middlewares.forEach { middleware in
                group.addTask {
                    await middleware.process(state: state, with: action, using: dependencies)
                }
            }
            
            for await case let nextAction? in group where !Task.isCancelled {
                await send(nextAction)
            }
        }
    }
}

extension Store {
    /// Use this method to create another `Store` deriving from the current one.
    public func derived<DerivedState: Equatable, DerivedAction: Equatable>(
        deriveState: @escaping (State) -> DerivedState,
        deriveAction: @escaping (DerivedAction) -> Action
    ) -> Store<DerivedState, DerivedAction, Void> {
        let derived = Store<DerivedState, DerivedAction, Void>(
            initialState: deriveState(state),
            reducer: IdentityReducer(),
            middlewares: [
                SendableMiddleware { _, action, _ in
                    await self.send(deriveAction(action))
                    return nil
                }
            ]
        )
        
        $state
            .map(deriveState)
            .removeDuplicates()
            .assign(to: &derived.$state)
        
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
            get: { extract(self.state) },
            set: { newValue in Task { await self.send(embed(newValue)) } }
        )
    }
}

extension Store {
    /// Use this initializer to create an instance of `Store` without dependencies.
    public convenience init(
        initialState state: State,
        reducer: some Reducer<State, Action>,
        middlewares: some Collection<any Middleware<State, Action, Void>>
    ) where Dependencies == Void {
        self.init(
            initialState: state,
            reducer: reducer,
            dependencies: (),
            middlewares: middlewares
        )
    }
}
