//
//  Prism.swift
//  UnidirectionalFlow
//
//  Created by Majid Jabrayilov on 23.06.22.
//
public struct Prism<Source, Target> {
    let embed: (Target) -> Source
    let extract: (Source) -> Target?
    
    public init(
        embed: @escaping (Target) -> Source,
        extract: @escaping (Source) -> Target?
    ) {
        self.embed = embed
        self.extract = extract
    }
}
