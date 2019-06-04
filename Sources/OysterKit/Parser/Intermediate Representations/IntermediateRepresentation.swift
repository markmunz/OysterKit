//    Copyright (c) 2016, RED When Excited
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
 Nodes are the basic elements of `IntermediateRepresentation`s. They record a `TokenType`, the range of the `String`'s `UnicodeScalarView` the match occured in
 as well as any annotations that were made on the token.

 */
public protocol Node : CustomStringConvertible{
    /// The token representing the match
    var token               : TokenType { get }
    
    /// The range of the match in the original source
    var range               : Range<String.UnicodeScalarView.Index> { get }
    
    /// Annotations that were made on the token
    var annotations         : [RuleAnnotation : RuleAnnotationValue] {get}
    
    /// Any sub-nodes in the tree
    var children       : [Self] {get}

    /**
     Create a new instance of the node
     
     Parameter for: The token that has been matched
     Parameter range: The range of the match
     Parameter annotations: The annotations that were made on the token
     */
    init(`for` token:TokenType, at range:Range<String.UnicodeScalarView.Index>, annotations: [RuleAnnotation:RuleAnnotationValue])
}

/**
 An `IntermediateRepresentation` is responsible for building this structure, typically some kind of Abstract Syntax Tree (AST).
 There are some other examples of this such as `DebuggingDelegate` or `ForkedIR`. It does this by observing the state changes in the
 matcher (such as start and end of evaluation of a rule). See below for standard implementations of this protocol that you can use. 
 
 - SeeAlso: `HomogenousAST`, `HeterogeneousAST`, `DebuggingIR`, `ForwardingIR`
 */
public protocol IntermediateRepresentation : class {
    init()

    /**
     Called when the parser is about to evaluate a structural rule. This is an oppertunity to prepare any appropriate data structures.
     
     - Parameter token: The token that will be created if the rule is matched
     */
    func evaluating(_ token:TokenType)
    
    /**
     Called after the `TokenType` has been successfully matched (or an ignorable failure for a pinned token)
     
     - Parameter token: The `TokenType` that has been evaluated
     - Parameter annotations: Any annotations required for the resultant node
     - Parameter range: The range of the match
     */
    func succeeded(token:TokenType, annotations:RuleAnnotations,  range:Range<String.Index>)
    
    /**
      Called when a token being evaluated failed to be matched
    */
    func failed()
    
    /**
     Called when the parser starts evaluation providing an oppertunity for the AST to prepare it's internal state.
    */
    func willBuildFrom(source:String, with: Grammar)
    
    /**
     Called when parsing of the source is complete.
    */
    func didBuild()
    
    /// Called if the state of parsing should be completely reset
    func resetState()
}
