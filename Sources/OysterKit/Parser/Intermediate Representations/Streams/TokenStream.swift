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
 A ``TokenStream`` provides lazy iterators that minimize memory consumption and overhead allowing you to iterate through the tokens created by the
 root rules (those at the lowest level in the language) in the supplied ``Grammar``
 */
public class TokenStream : Sequence{
    /// The iterator implementation to use
    public typealias Iterator =  TokenStreamIterator
    
    /// The lexer to use for the iterator
    let lexerType   : LexicalAnalyzer.Type
    
    /// The grammar to use to parse
    let grammar    : Grammar
    
    /// The source ``String`` to parse
    let source      : String
    
    public init(_ source:String, using grammar:Grammar){
        self.source = source
        self.lexerType = Lexer.self
        self.grammar = grammar
    }

    public init<Lex:LexicalAnalyzer>(_ source:String, using grammar:Grammar, with lexer:Lex.Type){
        self.lexerType = lexer
        self.grammar = grammar
        self.source = source
    }
    
    public func makeIterator() -> Iterator {
        return TokenStreamIterator(with: lexerType.init(source: source), and: grammar)
    }

}

/// The elements generated during streaming. These are very light-weight and are the same
/// as those used as an intermediate representation when building an ``AbstractSyntaxTree``
public typealias StreamedToken = AbstractSyntaxTreeConstructor.IntermediateRepresentationNode

/// The Iterator created by token streams
public class TokenStreamIterator : IteratorProtocol {
    /// The iterator generates elements of type ``StreamedToken``
    public typealias Element = StreamedToken

    /// Any errors encountered during parsing
    public private (set) var parsingErrors = [Error]()
    
    /// **DO NOT CALL**
    public required init() {
        fatalError("Do not create an instance of this object directly")
    }
    
    /**
     Creates a new instance of the iterator
     
     - Parameter lexer: The ``LexicalAnalyzer`` to use
     - Parameter grammar: The ``Language`` to use
    */
    init(with lexer:LexicalAnalyzer, and grammar:Grammar){
        parsingContext = ParsingStrategy.ParsingContext(lexer: lexer, ir: self, grammar: grammar)
    }
    
    /**
     Fetches the next matching token
     
     - Return: The generated token or nil
    */
    public func next() -> StreamedToken? {
        if parsingContext.lexer.endOfInput {
            return nil
        }
        
        let startingPosition = parsingContext.lexer.position
        
        nextToken = nil
        resetState()
        willBuildFrom(source: parsingContext.lexer.source, with: parsingContext.grammar)
        
        do {
            if try ParsingStrategy.pass(in: parsingContext) == false{
                nextToken = nil
            }
        } catch {
            parsingErrors.append(error)
            nextToken = nil
        }
        
        if let nextToken = nextToken {
            return nextToken
        } else {
            if startingPosition != parsingContext.lexer.position {
                return next()
            }
            return nil
        }
    }
    
    /// True if parsing reached the end of input naturally (that is, encountered no errors)
    public var reachedEndOfInput  : Bool {
        return parsingContext.complete
    }
    
    /// This must be force unwrapped as the parsing context requies this object in its initializer.
    var parsingContext     : ParsingStrategy.ParsingContext!
    
    /// Track the depth of evaluation
    var depth              = 0
    
    /// The token generated during the last pass
    var nextToken          : StreamedToken?
    
}

/// This iterator is a very light weight intermediate representation that only constructs top level nodes
extension TokenStreamIterator : IntermediateRepresentation {

    public func evaluating(_ token: TokenType) {
        depth += 1
    }
    
    public func succeeded(token: TokenType, annotations: RuleAnnotations, range: Range<String.Index>) {
        depth -= 1
        if depth == 1  {
            nextToken = StreamedToken(for: token, at: range, annotations: annotations)
        }
    }
    
    public func failed() {
        depth -= 1
        if depth == 1 {
            nextToken = nil
        }
    }
    
    /// Sets the initial depth to 1
    public func willBuildFrom(source: String, with: Grammar) {
        depth = 1
    }
    
    /// Disables further evaluation
    public func didBuild() {
        depth = 0
    }
    
    /// Disables further evaluation
    public func resetState() {
        depth = 0
    }

}

