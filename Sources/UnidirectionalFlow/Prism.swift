//
//  Prism.swift
//  UnidirectionalFlow
//
//  Created by Majid Jabrayilov on 23.06.22.
//

/// Type that defines a way to embed and extract a value from another type.
public struct Prism<Source, Target>: Sendable {
    let embed: @Sendable (Target) -> Source
    let extract: @Sendable (Source) -> Target?
    
    public init(
        embed: @Sendable @escaping (Target) -> Source,
        extract: @Sendable @escaping (Source) -> Target?
    ) {
        self.embed = embed
        self.extract = extract
    }
}
