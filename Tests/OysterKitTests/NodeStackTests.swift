//    Copyright (c) 2014, RED When Excited
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

import XCTest
@testable import OysterKit

struct TestNode : Node, CustomStringConvertible {
    var token: TokenType
    
    var range: Range<String.UnicodeScalarView.Index>
    
    var annotations: [RuleAnnotation : RuleAnnotationValue]
    
    var children: [TestNode]
    
    init(for token: TokenType, at range: Range<String.UnicodeScalarView.Index>, annotations: [RuleAnnotation : RuleAnnotationValue]) {
        self.token = token
        self.range = range
        self.annotations = annotations
        children = [TestNode]()
    }
    
    var description: String {
        return "\(token)"
    }
}

class NodeStackTests: XCTestCase {

    func testNodeStackDepth() {
        let stack = NodeStack<TestNode>()
        
        XCTAssertEqual(1, stack.depth)
        stack.push()
        XCTAssertEqual(2, stack.depth)
        let _ = stack.pop()
        XCTAssertEqual(1, stack.depth)
    }
    
    func testAll(){
        let source = "Hello world good to meet you"
        let stack = NodeStack<TestNode>()
        
        stack.top?.append(TestNode(for: StringToken("hello"), at: source.range(of: "Hello")!, annotations: [:]))
        stack.push()
        stack.top?.append(TestNode(for: StringToken("world"), at: source.range(of: "world")!, annotations: [:]))
        stack.top?.append(TestNode(for: StringToken("good"), at: source.range(of: "good")!, annotations: [:]))
        
        //Key thing is 2 nodes first to make sure it has been reversed
        XCTAssertEqual(stack.all.description,"[2 nodes, 1 nodes]")
    }
    
    func testArrayAppend(){
        var     setLikeArray = [Int]()
        
        XCTAssertEqual(0, setLikeArray.count)
        setLikeArray.append(unique: 0)
        XCTAssertEqual(1, setLikeArray.count)
        setLikeArray.append(unique: 0)
        XCTAssertEqual(1, setLikeArray.count)
        setLikeArray.append(unique: 1)
        XCTAssertEqual(2, setLikeArray.count)
        XCTAssertTrue(setLikeArray.contains(1))
        XCTAssertTrue(setLikeArray.contains(0))
    }
    
    func testDescription(){
        let source = "Hello"
        let nodeStack = NodeStack<TestNode>()

        nodeStack.top?.append(TestNode(for: StringToken("hello"), at: source.startIndex..<source.endIndex, annotations: [
            RuleAnnotation.void : RuleAnnotationValue.set
            ]))
        
        nodeStack.push()

        XCTAssertEqual(nodeStack.description, "NodeStack: \n0 nodes\n1 nodes\n")
        
    }
}
