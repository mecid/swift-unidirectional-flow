//
//  PrismTests.swift
//  UnidirectionalFlowTests
//
//  Created by Majid Jabrayilov on 07.07.22.
//
@testable import UnidirectionalFlow
import XCTest

final class PrismTests: XCTestCase {
    enum LeftAction: Equatable {
        case action
    }
    
    enum RightAction: Equatable {
        case action
    }
    
    enum Action: Equatable {
        case left(LeftAction)
        case right(RightAction)
        
        static var leftPrism: Prism<Action, LeftAction> {
            Prism(embed: Action.left) {
                guard case let Action.left(action) = $0 else {
                    return nil
                }
                return action
            }
        }
    }
    
    func testExtract() {
        XCTAssertNil(Action.leftPrism.extract(Action.right(.action)))
        XCTAssertEqual(Action.leftPrism.extract(Action.left(.action)), LeftAction.action)
    }
    
    func testEmbed() {
        XCTAssertEqual(Action.leftPrism.embed(.action), Action.left(.action))
    }
}
