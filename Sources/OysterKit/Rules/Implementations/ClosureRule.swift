//    Copyright (c) 2018, RED When Excited
//    All rights reserved.
//
//    Redistribution and use in source and binary forms, with or without
//    modification, are permitted provided that the following conditions are met:
//
//    * Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
//    * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//    FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//    SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation

/**
 An implementation of a `Rule` that allows the specification of a `Test`
 closure to provide the required check.
 */
public final class ClosureRule : Rule {
    /// Annotations for the rule
    public let annotations: RuleAnnotations

    /// Behaviour for the rule
    public let behaviour: Behaviour
    
    /// The `Test` closure used by the rule
    public let matcher : Test

    /**
     Create a an instance supplied annotations and token that will use the supplied `Test` closure
     to perform its match
     
     - Parameter token: The new ``TokenType`` or ``nil`` if the token should remain the same
     - Parameter annotations: The new ``Annotations`` or ``nil`` if the annotations are unchanged
     - Parameter matcher: The `Test` closure
     */
    public init(with behaviour:Behaviour, and annotations:RuleAnnotations = [:], using matcher:@escaping Test){
        self.behaviour = behaviour
        self.annotations = annotations
        self.matcher = matcher
        
        assert((structural && behaviour.lookahead) == false, "Lookahead rules cannot be structural as their match range will always be 0")
        assert((behaviour.negate && behaviour.cardinality.minimumMatches == 0) == false, "Cannot negate an optional (minimum cardinality is 0) rule (negating an ignorable failure makes no sense).")
    }
    
    
    /**
     This function should create a new instance of this rule, replacing the behaviour and
     any annotations with those specified in the parameters if not nil, or maintaining the
     current ones if nil.
     
     - Parameter behaviour: The behaviour for the new instance, if nil the new copy should
     use the same behaviour as this instance.
     - Parameter annotations: The annotations for the new instance, if nil the new copy
     should use the same behaviour as this instance.
     - Returns: A new instance with the specified behaviour and annotations.
     */
    public func rule(with behaviour: Behaviour? = nil, annotations: RuleAnnotations? = nil) -> Rule {
        let newBehaviour = behaviour ?? self.behaviour
        let newAnnotations = annotations ?? self.annotations
        
        return ClosureRule(with: newBehaviour, and: newAnnotations, using: matcher)
    }

    /**
     This function implements the actual test. It is responsible soley for performing
     the test. The scanner head will be managed correctly based on success (it will be
     left in the position at the end of the test), or returned to its pre-test position
     on failure.
     
     - Parameter lexer: The lexer controlling the scanner
     - Parameter ir: The intermediate representation
     */
    public func test(with lexer: LexicalAnalyzer, for ir: IntermediateRepresentation) throws {
        try matcher(lexer,ir)
    }

    /// A textual description of the rule
    public var description: String{
        return behaviour.describe(match:"{closure}", annotatedWith: annotations)
    }
    
    /// An abreviated description of the rule
    public var shortDescription: String{
        if let produces = behaviour.token {
            return behaviour.describe(match: "\(produces)", requiresStructuralPrefix: false, annotatedWith: annotations)
        }
        return behaviour.describe(match: "{closure}", annotatedWith: annotations)
    }

    
}
