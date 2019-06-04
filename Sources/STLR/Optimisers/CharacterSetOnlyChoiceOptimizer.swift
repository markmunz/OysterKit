//
//  TerminalExpressionOptimizer.swift
//  OysterKit
//
//  
//  Copyright © 2016 RED When Excited. All rights reserved.
//

import Foundation

private extension STLR.Element{
    var combineable : Bool {
        if cardinality != .one || isLookahead || annotations != nil {
            return false
        }
        if let terminal = terminal {
            switch terminal {
                case .terminalString(let string):
                    return string.terminalBody.count == 1
                case .characterRange(_), .characterSet(_):
                    return true
                default:
                    return false
            }
        }
        return false
    }
}

public struct CharacterSetOnlyChoiceOptimizer : STLRExpressionOptimizer{
    private typealias Quantifier           = STLR.Quantifier
    private typealias Element              = STLR.Element
    private typealias Expression           = STLR.Expression
    private typealias TerminalCharacterSet = STLR.CharacterSet
    private typealias Terminal             = STLR.Terminal
    
    public init(){
        
    }
    
    //
    // Combines multiple elements which have only terminals that can be represented as single character sets
    // as a combined single character set
    //
    private func characterSetsByCombiningChoiceOfSingleCharacters(elements:[Element]) -> TerminalCharacterSet? {
//        if elements.count == 0 {
//            return nil
//        }
//
//        var characters = ""
//        for element in elements{
//            if !element.annotations.isEmpty{
//                return nil
//            }
//            switch element{
//
//            case .terminal(let terminal, let quantifier,_,_):
//                if let string = terminal.string , string.count == 1, quantifier == .one {
//                    characters +=  string
//                } else {
//                    return nil
//                }
//            default: return nil
//            }
//        }
//
//        if characters.count == elements.count {
//            return TerminalCharacterSet.customString(characters)
//        }
//
        return nil
    }
    
    
    private func characterSetByCombiningOtherSets(elements:[Element])->TerminalCharacterSet? {
//        for element in elements {
//            if !element.elementAnnotations.isEmpty{
//                return nil
//            }
//        }
//
//        if elements.count == 1 {
//            switch elements[0]{
//            case .terminal(let terminal, let quantifier,_,_) where quantifier == .one:
//                return terminal.characterSet
//            default: return nil
//            }
//        }
//        var characterSets = [TerminalCharacterSet]()
//        for element in elements{
//            switch element{
//            case .terminal(let terminal, let quantifier,_,_):
//                if let characterSet = terminal.characterSet, quantifier == .one{
//                    characterSets.append(characterSet)
//                } else {
//                    return nil
//                }
//            default: return nil
//            }
//        }
//
//        if characterSets.count == elements.count {
//            return TerminalCharacterSet.multipleSets(characterSets)
//        }
//
        return nil
    }
    
    private func createCharacterSet(elements:[Element])->TerminalCharacterSet? {
        if let newSet = characterSetByCombiningOtherSets(elements: elements){
            return newSet
        } else if let newSet = characterSetsByCombiningChoiceOfSingleCharacters(elements: elements){
            return newSet
        }
        
        return nil
    }
    
    private func createCharacterSetElement(elements:[Element])->Element?{
//        if let characterSet = createCharacterSet(elements: elements){
//            return Element(Terminal(with: characterSet), Quantifier.one)
//        } else {
            return nil
//        }
    }
    
    public func optimize(expression: STLR.Expression) -> STLR.Expression? {
//        var others                      = [Element]()
//        var combineableCharacterSets    = [Element]()
//        var stringCharacterSets         = [Element]()
//
//        var othersHasOptimizations      = false
//
//        var originalSize = 0
//
//        // Split them into things which can be character sets and things that can't be
//        switch expression{
//        case .element(let element):
//            if case Element.group(let groupExpression, let quantifier,_,_) = element {
//                if let optimizedGroup = optimize(expression: groupExpression) {
//                    return Expression.element(Element(optimizedGroup, quantifier))
//                }
//            }
//            return nil
//        case .choice(let elements):
//            originalSize = elements.count
//            for element in elements {
//                if element.singleCharacterTerminal {
//                    stringCharacterSets.append(element)
//                } else if let csElement = createCharacterSetElement(elements:[element]){
//                    combineableCharacterSets.append(csElement)
//                } else if case Element.group(let groupExpression, let quantifier,_,_) = element, let optimizedGroupExpression = optimize(expression: groupExpression) {
//                    othersHasOptimizations = true
//                    others.append(Element(optimizedGroupExpression, quantifier))
//                } else {
//                    others.append(element)
//                }
//            }
//        case .sequence(let elements):
//            var optimizedElements = [Element]()
//            for element in elements {
//                if case Element.group(let groupExpression, let quantifier,_,_) = element, let optimizedGroupExpression = optimize(expression: groupExpression) {
//                    optimizedElements.append(Element(optimizedGroupExpression, quantifier))
//                    othersHasOptimizations = true
//                } else {
//                    optimizedElements.append(element)
//                }
//            }
//            if othersHasOptimizations{
//                return Expression.sequence(optimizedElements)
//            } else {
//                return nil
//            }
//        case .group:
//            return nil
//        }
//
//        // If there is nothing combinable, might as well bug out
//        if combineableCharacterSets.count == 0 && stringCharacterSets.count == 0 {
//            if othersHasOptimizations {
//                return Expression.choice(others)
//            } else {
//                return nil
//            }
//        }
//
//        // Fold up any single character string sets into a single set
//        if let stringCharacterSet = characterSetsByCombiningChoiceOfSingleCharacters(elements: stringCharacterSets) {
//            combineableCharacterSets.append(Element(Terminal(with: stringCharacterSet), Quantifier.one))
//        }
//
//        // From this point on the code will assume that combinable character sets contains everything it needs to optimize
//        // anything else will be in others
//
//        // If it has already resolved down to a single character set then use that
//        if combineableCharacterSets.count == 1 && others.count == 0{
//            return Expression.element(combineableCharacterSets[0])
//        }
//
//        // Try folding and ifwe can't, then combine what we have
//        guard let csElement = createCharacterSetElement(elements: combineableCharacterSets) else {
//            others.append(contentsOf: combineableCharacterSets)
//
//           //If there's no difference in the number of elements in the expression, we've failed
//            if others.count == originalSize {
//                return nil
//            }
//
//            return Expression.choice(others)
//        }
//
//        if others.count == 0 {
//            return Expression.element(csElement)
//        }
//
//        others.append(csElement)
//
//        //If there's no difference in the number of elements in the expression, we've failed
//        if others.count == originalSize {
//            return nil
//        }
//
//        return Expression.choice(others)
        return nil
    }
    
    public var description: String{
        return "Optimizes expressions with choices of multiple terminals"
    }
}
