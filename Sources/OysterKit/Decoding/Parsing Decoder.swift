//
//  STLR Decoder.swift
//  OysterKit
//
// Createed with heavy reference to: https://github.com/apple/swift-corelibs-foundation/blob/master/Foundation/JSONEncoder.swift#L802
//
//  Created on 01/09/2017.
//  Copyright © 2017 RED When Excited. All rights reserved.
//

import Foundation

public protocol DecodeableNode{
    func stringValue(source : String)->String
    var  key                : CodingKey {get}
    var  contents           : [DecodeableNode] {get}
    subscript(_ index:Int)->DecodeableNode {get}
    subscript(key codingKey:CodingKey)->DecodeableNode? {get}
}

public extension DecodeableNode{
    public subscript(key codingKey: CodingKey) -> DecodeableNode? {
        for child in contents {
            if child.key.stringValue == codingKey.stringValue {
                return child
            }
        }
        return nil
    }
    public subscript(_ index: Int) -> DecodeableNode {
        return contents[index]
    }
}

extension CodingKey {
    func equals(rhs:CodingKey)->Bool{
        guard let lhsInt = self.intValue, let rhsInt = rhs.intValue else {
            return self.stringValue == rhs.stringValue
        }
        
        return lhsInt == rhsInt
    }
}

extension HeterogenousAST : DecodeableNode {
    public func stringValue(source: String) -> String {
        return children[0].matchedString(source)
    }
    
    public var key: CodingKey {
        return (children[0] as! DecodeableNode).key
    }
    
    public var contents: [DecodeableNode] {
        return children[0].value as! [DecodeableNode]
    }
    
    
}

extension HeterogeneousNode : DecodeableNode{
    

    
    public var contents: [DecodeableNode] {
        return value as? [HeterogeneousNode] ?? []
    }
    
    public func stringValue(source: String) -> String {
        return matchedString(source)
    }
    
    public var key: CodingKey {
        return _ParsingKey(token: token)
    }
    
    
}

internal func prettyPrint(nodes:[HeterogeneousNode], from source:String, indenting indent:String=""){
    for node in nodes {
        if node.children.isEmpty {
            print("\(indent)\(node.token) = \(node.matchedString(source))")
        } else {
            print("\(indent)\(node.token)")
            prettyPrint(nodes: node.children, from:source, indenting: indent + "\t")
        }
    }
}

public struct ParsingDecoder{
    
    public init(){
        
    }
    
    public func decode<T>(_ type: T.Type, from data: Data, with parser:Parser) throws -> T where T : Decodable{
        guard let source = String(data: data,encoding: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Data is not in utf8 format"))
        }
        
        let topLevel : DefaultHeterogeneousAST = parser.build(source: source)

        prettyPrint(nodes: topLevel.children, from: source)
        
        if topLevel.children.count == 0 {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Could not parse supplied string"))
        }
        
        let decoder = _ParsingDecoder(referencing: topLevel, from: source)
        return try T(from: decoder)
    }
    
    
}

fileprivate class _ParsingDecoder : Decoder{
    // MARK: Properties
    /// The decoder's storage.
    fileprivate var storage: _ParsingDecodingStorage
    
    /// The path to the current point in encoding.
    private(set) public var codingPath: [CodingKey]
    
    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey : Any] = [:]
    
    // MARK: - Initialization
    /// Initializes `self` with the given top-level container and options.
    fileprivate init(referencing container: DecodeableNode, at codingPath: [CodingKey] = [], from source:String) {
        self.storage = _ParsingDecodingStorage(source)
        self.storage.push(container: container)
        self.codingPath = codingPath
    }
    
    // MARK: - Coding Path Operations
    /// Performs the given closure with the given key pushed onto the end of the current coding path.
    ///
    /// - parameter key: The key to push. May be nil for unkeyed containers.
    /// - parameter work: The work to perform with the key in the path.
    fileprivate func with<T>(pushedKey key: CodingKey, _ work: () throws -> T) rethrows -> T {
        self.codingPath.append(key)
        let ret: T = try work()
        self.codingPath.removeLast()
        return ret
    }
    
    // MARK: - Decoder Methods
    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        let topContainer = storage.topContainer
        
        let container = _ParsingKeyedDecodingContainer<Key>(referencing: self, wrapping: topContainer)
        return KeyedDecodingContainer(container)
    }
    
    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        let topContainer = self.storage.topContainer
        
        return _STLRUnkeyedDecodingContainer(referencing: self, wrapping: topContainer)
    }
    
    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        return self
    }
}

fileprivate struct _ParsingDecodingStorage {
    // MARK: Properties
    /// The container stack.
    /// Elements may be any one of the JSON types (NSNull, NSNumber, String, Array, [String : Any]).
    private(set) fileprivate var containers: [DecodeableNode] = []
    
    // MARK: - Initialization
    /// Initializes `self` with no containers.
    fileprivate init(_ source:String) {
        self.source = source
        
    }
    
    var source : String
    
    // MARK: - Modifying the Stack
    fileprivate var count: Int {
        return self.containers.count
    }
    
    fileprivate var topContainer: DecodeableNode {
        precondition(self.containers.count > 0, "Empty container stack.")
        return self.containers.last!
    }
    
    fileprivate mutating func push(container: DecodeableNode) {
        self.containers.append(container)
    }
    
    fileprivate mutating func popContainer() {
        precondition(self.containers.count > 0, "Empty container stack.")
        self.containers.removeLast()
    }
}

fileprivate struct TokenKey: Token, CodingKey{
    var rawValue: Int
    var stringValue: String
    
    
    init(token:Token){
        rawValue = token.rawValue
        stringValue = "\(token)"
    }
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.rawValue = 0
    }
    
    var intValue: Int? {
        return rawValue
    }
    
    init?(intValue: Int) {
        rawValue = intValue
        stringValue = "\(intValue)"
    }
    
    
}

fileprivate struct _ParsingKeyedDecodingContainer<K : CodingKey> : KeyedDecodingContainerProtocol {
    typealias Key = K
    
    // MARK: Properties
    /// A reference to the decoder we're reading from.
    private let decoder: _ParsingDecoder
    
    /// A reference to the container we're reading from.
    private let container: DecodeableNode
    
    /// The path of coding keys taken to get to this point in decoding.
    private(set) public var codingPath: [CodingKey]
    
    // MARK: - Initialization
    /// Initializes `self` by referencing the given decoder and container.
    fileprivate init(referencing decoder: _ParsingDecoder, wrapping container: DecodeableNode) {
        self.decoder = decoder
        self.container = container
        self.codingPath = decoder.codingPath
    }
    
    // MARK: - KeyedDecodingContainerProtocol Methods
    public var allKeys: [Key] {
        return container.contents.map { (node) -> CodingKey in
            node.key
        } as! [K]
    }
    
    public func contains(_ key: Key) -> Bool {
        //This can't be right
        return self.container[key: key] != nil
    }
    
    public func decodeNil(forKey key: Key) throws -> Bool {
        guard let _ = self.container[key: key] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        //If it's there, it's not nil
        return false
    }
    
    public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        guard let entry = self.container[key: key] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        return try self.decoder.with(pushedKey: key) {
            guard let value = try self.decoder.unbox(entry, as: Bool.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
            }
            
            return value
        }
    }
    
    public func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        guard let entry = self.container[key: key] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        guard let result = Int(entry.stringValue(source: decoder.source)) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) but couldn't convert \(entry) to it"))
        }
        
        return result
        
    }
    
    public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        guard let entry = self.container[key: key] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        guard let result = Int8(entry.stringValue(source: decoder.source)) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) but couldn't convert \(entry) to it"))
        }
        
        return result
    }
    
    public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        guard let entry = self.container[key: key] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        guard let result = Int16(entry.stringValue(source: decoder.source)) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) but couldn't convert \(entry) to it"))
        }
        
        return result
    }
    
    public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        guard let entry = self.container[key: key] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        guard let result = Int32(entry.stringValue(source: decoder.source)) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) but couldn't convert \(entry) to it"))
        }
        
        return result
    }
    
    public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        guard let entry = self.container[key: key] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        guard let result = Int64(entry.stringValue(source: decoder.source)) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) but couldn't convert \(entry) to it"))
        }
        
        return result
    }
    
    public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        guard let entry = self.container[key: key] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        guard let result = UInt(entry.stringValue(source: decoder.source)) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) but couldn't convert \(entry) to it"))
        }
        
        return result
    }
    
    public func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        guard let entry = self.container[key: key] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        guard let result = UInt8(entry.stringValue(source: decoder.source)) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) but couldn't convert \(entry) to it"))
        }
        
        return result
    }
    
    public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        guard let entry = self.container[key: key] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        guard let result = UInt16(entry.stringValue(source: decoder.source)) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) but couldn't convert \(entry) to it"))
        }
        
        return result
    }
    
    public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        guard let entry = self.container[key: key] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        guard let result = UInt32(entry.stringValue(source: decoder.source)) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) but couldn't convert \(entry) to it"))
        }
        
        return result
    }
    
    public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        guard let entry = self.container[key: key] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        guard let result = UInt64(entry.stringValue(source: decoder.source)) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) but couldn't convert \(entry) to it"))
        }
        
        return result
    }
    
    public func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        guard let entry = self.container[key: key] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        guard let result = Float(entry.stringValue(source: decoder.source)) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) but couldn't convert \(entry) to it"))
        }
        
        return result
    }
    
    public func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        guard let entry = self.container[key: key] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        guard let result = Double(entry.stringValue(source: decoder.source)) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) but couldn't convert \(entry) to it"))
        }
        
        return result
    }
    
    public func decode(_ type: String.Type, forKey key: Key) throws -> String {
        guard let entry = self.container[key: key] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        let stringValue = entry.stringValue(source: self.decoder.source)
        
        return stringValue
    }
    
    public func decode<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        guard let entry = self.container[key: key] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        
        return try self.decoder.with(pushedKey: key) {
            guard let value = try self.decoder.unbox(entry, as: T.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
            }
            
            return value
        }
    }
    
    public func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        return try self.decoder.with(pushedKey: key) {
            guard let value = self.container[key: key] else {
                throw DecodingError.keyNotFound(key,
                                                DecodingError.Context(codingPath: self.codingPath,
                                                                      debugDescription: "Cannot get \(KeyedDecodingContainer<NestedKey>.self) -- no value found for key \"\(key.stringValue)\""))
            }
            
//            guard let dictionary = value as? [String : Any] else {
//                throw DecodingError._typeMismatch(at: self.codingPath, expectation: [String : Any].self, reality: value)
//            }
            
            let container = _ParsingKeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: value)
            return KeyedDecodingContainer(container)
        }
    }
    
    public func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        return try self.decoder.with(pushedKey: key) {
            guard let value = self.container[key: key] else {
                throw DecodingError.keyNotFound(key,
                                                DecodingError.Context(codingPath: self.codingPath,
                                                                      debugDescription: "Cannot get UnkeyedDecodingContainer -- no value found for key \"\(key.stringValue)\""))
            }
            
//            guard let array = value as? [Any] else {
//                throw DecodingError._typeMismatch(at: self.codingPath, expectation: [Any].self, reality: value)
//            }
            
            //Or should it be value.children and something clever
            return _STLRUnkeyedDecodingContainer(referencing: self.decoder, wrapping: value)
        }
    }
    
    private func _superDecoder(forKey key: CodingKey) throws -> Decoder {
        return self.decoder.with(pushedKey: key) {
            let value = self.container[key: key]
            return _ParsingDecoder(referencing: value!, at: self.decoder.codingPath, from: decoder.storage.source)
        }
    }
    
    public func superDecoder() throws -> Decoder {
        return try _superDecoder(forKey: _ParsingKey.super)
    }
    
    public func superDecoder(forKey key: Key) throws -> Decoder {
        return try _superDecoder(forKey: key)
    }
}

fileprivate struct _ParsingKey : CodingKey{
    public var stringValue: String
    
    init(token:Token){
        stringValue = "\(token)"
        intValue = token.rawValue
    }
    
    init(index:Int){
        stringValue="Index \(index)"
        intValue = index
    }
    
    public init?(stringValue: String) {
        return nil
    }
    
    public var intValue: Int?
    
    public init?(intValue: Int) {
        return nil
    }
    
    static var `super` : _ParsingKey {
        fatalError()
    }
    
    
}

extension _ParsingDecoder : SingleValueDecodingContainer{
    
    var node : DecodeableNode {
        return storage.topContainer
    }
    
    var source : String {
        return storage.source
    }
    
    func decodeNil() -> Bool {
        return false
    }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        if let boolValue = type.init(node.stringValue(source: source)){
            return boolValue
        }
        
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "\(node.stringValue(source: source)) can't be represented as a \(type)"))
    }
    
    func decode(_ type: Int.Type) throws -> Int {
        if let value = type.init(node.stringValue(source: source)){
            return value
        }
        
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "\(node.stringValue(source: source)) can't be represented as a \(type)"))
    }
    
    func decode(_ type: Int8.Type) throws -> Int8 {
        if let value = type.init(node.stringValue(source: source)){
            return value
        }
        
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "\(node.stringValue(source: source)) can't be represented as a \(type)"))
    }
    
    func decode(_ type: Int16.Type) throws -> Int16 {
        if let value = type.init(node.stringValue(source: source)){
            return value
        }
        
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "\(node.stringValue(source: source)) can't be represented as a \(type)"))
    }
    
    func decode(_ type: Int32.Type) throws -> Int32 {
        if let value = type.init(node.stringValue(source: source)){
            return value
        }
        
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "\(node.stringValue(source: source)) can't be represented as a \(type)"))
    }
    
    func decode(_ type: Int64.Type) throws -> Int64 {
        if let value = type.init(node.stringValue(source: source)){
            return value
        }
        
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "\(node.stringValue(source: source)) can't be represented as a \(type)"))
    }
    
    func decode(_ type: UInt.Type) throws -> UInt {
        if let value = type.init(node.stringValue(source: source)){
            return value
        }
        
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "\(node.stringValue(source: source)) can't be represented as a \(type)"))
    }
    
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        if let value = type.init(node.stringValue(source: source)){
            return value
        }
        
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "\(node.stringValue(source: source)) can't be represented as a \(type)"))
    }
    
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        if let value = type.init(node.stringValue(source: source)){
            return value
        }
        
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "\(node.stringValue(source: source)) can't be represented as a \(type)"))
    }
    
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        if let value = type.init(node.stringValue(source: source)){
            return value
        }
        
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "\(node.stringValue(source: source)) can't be represented as a \(type)"))
    }
    
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        if let value = type.init(node.stringValue(source: source)){
            return value
        }
        
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "\(node.stringValue(source: source)) can't be represented as a \(type)"))
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        if let value = type.init(node.stringValue(source: source)){
            return value
        }
        
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "\(node.stringValue(source: source)) can't be represented as a \(type)"))
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        if let value = type.init(node.stringValue(source: source)){
            return value
        }
        
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "\(node.stringValue(source: source)) can't be represented as a \(type)"))
    }
    
    func decode(_ type: String.Type) throws -> String {
        return node.stringValue(source: source)
    }
    
    public func decode<T : Decodable>(_ type: T.Type) throws -> T {
        try expectNonNull(T.self)
        return try self.unbox(self.storage.topContainer, as: T.self)!
    }

    private func expectNonNull<T>(_ type: T.Type) throws {
        guard !self.decodeNil() else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected \(type) but found null value instead."))
        }
    }
}

fileprivate struct _STLRUnkeyedDecodingContainer : UnkeyedDecodingContainer {
    // MARK: Properties
    /// A reference to the decoder we're reading from.
    private let decoder: _ParsingDecoder
    
    /// A reference to the container we're reading from.
    private let container: DecodeableNode
    
    /// The path of coding keys taken to get to this point in decoding.
    private(set) public var codingPath: [CodingKey]
    
    /// The index of the element we're about to decode.
    private(set) public var currentIndex: Int
    
    // MARK: - Initialization
    /// Initializes `self` by referencing the given decoder and container.
    fileprivate init(referencing decoder: _ParsingDecoder, wrapping container: DecodeableNode) {
        self.decoder = decoder
        self.container = container
        self.codingPath = decoder.codingPath
        self.currentIndex = 0
    }
    
    // MARK: - UnkeyedDecodingContainer Methods
    public var count: Int? {
        return self.container.contents.count
    }
    
    public var isAtEnd: Bool {
        return self.currentIndex >= self.count!
    }
    
    public mutating func decodeNil() throws -> Bool {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(Any?.self, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(intValue: self.currentIndex)!], debugDescription: "Unkeyed container is at end."))
        }
        
        return false
    }
    
    public mutating func decode(_ type: Bool.Type) throws -> Bool {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Bool.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
            }
            
            self.currentIndex += 1
            return decoded
        }
    }
    
    public mutating func decode(_ type: Int.Type) throws -> Int {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
            }
            
            self.currentIndex += 1
            return decoded
        }
    }
    
    public mutating func decode(_ type: Int8.Type) throws -> Int8 {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int8.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
            }
            
            self.currentIndex += 1
            return decoded
        }
    }
    
    public mutating func decode(_ type: Int16.Type) throws -> Int16 {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int16.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
            }
            
            self.currentIndex += 1
            return decoded
        }
    }
    
    public mutating func decode(_ type: Int32.Type) throws -> Int32 {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int32.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
            }
            
            self.currentIndex += 1
            return decoded
        }
    }
    
    public mutating func decode(_ type: Int64.Type) throws -> Int64 {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Int64.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
            }
            
            self.currentIndex += 1
            return decoded
        }
    }
    
    public mutating func decode(_ type: UInt.Type) throws -> UInt {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
            }
            
            self.currentIndex += 1
            return decoded
        }
    }
    
    public mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt8.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
            }
            
            self.currentIndex += 1
            return decoded
        }
    }
    
    public mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt16.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
            }
            
            self.currentIndex += 1
            return decoded
        }
    }
    
    public mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt32.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
            }
            
            self.currentIndex += 1
            return decoded
        }
    }
    
    public mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: UInt64.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
            }
            
            self.currentIndex += 1
            return decoded
        }
    }
    
    public mutating func decode(_ type: Float.Type) throws -> Float {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Float.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
            }
            
            self.currentIndex += 1
            return decoded
        }
    }
    
    public mutating func decode(_ type: Double.Type) throws -> Double {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: Double.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
            }
            
            self.currentIndex += 1
            return decoded
        }
    }
    
    public mutating func decode(_ type: String.Type) throws -> String {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: String.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
            }
            
            self.currentIndex += 1
            return decoded
        }
    }
    
    public mutating func decode<T : Decodable>(_ type: T.Type) throws -> T {
        guard !self.isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard let decoded = try self.decoder.unbox(self.container[self.currentIndex], as: T.self) else {
                throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath + [_ParsingKey(index: self.currentIndex)], debugDescription: "Expected \(type) but found null instead."))
            }
            
            self.currentIndex += 1
            return decoded
        }
    }
    
    public mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard !self.isAtEnd else {
                throw DecodingError.valueNotFound(KeyedDecodingContainer<NestedKey>.self,
                                                  DecodingError.Context(codingPath: self.codingPath,
                                                                        debugDescription: "Cannot get nested keyed container -- unkeyed container is at end."))
            }
            
            let value = self.container[self.currentIndex]

            self.currentIndex += 1
            let container = _ParsingKeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: value)
            return KeyedDecodingContainer(container)
        }
    }
    
    public mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard !self.isAtEnd else {
                throw DecodingError.valueNotFound(UnkeyedDecodingContainer.self,
                                                  DecodingError.Context(codingPath: self.codingPath,
                                                                        debugDescription: "Cannot get nested keyed container -- unkeyed container is at end."))
            }
            
            let value = self.container[self.currentIndex]
//            guard !(value is NSNull) else {
//                throw DecodingError.valueNotFound(UnkeyedDecodingContainer.self,
//                                                  DecodingError.Context(codingPath: self.codingPath,
//                                                                        debugDescription: "Cannot get keyed decoding container -- found null value instead."))
//            }
//
//            guard let array = value as? [Any] else {
//                throw DecodingError._typeMismatch(at: self.codingPath, expectation: [Any].self, reality: value)
//            }
            
            self.currentIndex += 1
            return _STLRUnkeyedDecodingContainer(referencing: self.decoder, wrapping: value)
        }
    }
    
    public mutating func superDecoder() throws -> Decoder {
        return try self.decoder.with(pushedKey: _ParsingKey(index: self.currentIndex)) {
            guard !self.isAtEnd else {
                throw DecodingError.valueNotFound(Decoder.self,
                                                  DecodingError.Context(codingPath: self.codingPath,
                                                                        debugDescription: "Cannot get superDecoder() -- unkeyed container is at end."))
            }
            
            let value = self.container[self.currentIndex]
            self.currentIndex += 1
            return _ParsingDecoder(referencing: value, at: self.decoder.codingPath, from:decoder.storage.source)
        }
    }
}

extension _ParsingDecoder {
    /// Returns the given value unboxed from a container.
    fileprivate func unbox(_ value: Any, as type: Bool.Type) throws -> Bool? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) and got \(value)"))
        }
        
        // TODO: Add a flag to coerce non-boolean numbers into Bools?
//        guard number._cfTypeID == CFBooleanGetTypeID() else {
//            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) and got \(value)"))
//        }
        
        return number.boolValue
    }
    
    fileprivate func unbox(_ value: Any, as type: Int.Type) throws -> Int? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) and got \(value)"))
        }
        
        let int = number.intValue
        guard NSNumber(value: int) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }
        
        return int
    }
    
    fileprivate func unbox(_ value: Any, as type: Int8.Type) throws -> Int8? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) and got \(value)"))
        }
        
        let int8 = number.int8Value
        guard NSNumber(value: int8) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }
        
        return int8
    }
    
    fileprivate func unbox(_ value: Any, as type: Int16.Type) throws -> Int16? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) and got \(value)"))
        }
        
        let int16 = number.int16Value
        guard NSNumber(value: int16) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }
        
        return int16
    }
    
    fileprivate func unbox(_ value: Any, as type: Int32.Type) throws -> Int32? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) and got \(value)"))
        }
        
        let int32 = number.int32Value
        guard NSNumber(value: int32) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }
        
        return int32
    }
    
    fileprivate func unbox(_ value: Any, as type: Int64.Type) throws -> Int64? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) and got \(value)"))
        }
        
        let int64 = number.int64Value
        guard NSNumber(value: int64) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }
        
        return int64
    }
    
    fileprivate func unbox(_ value: Any, as type: UInt.Type) throws -> UInt? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) and got \(value)"))
        }
        
        let uint = number.uintValue
        guard NSNumber(value: uint) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }
        
        return uint
    }
    
    fileprivate func unbox(_ value: Any, as type: UInt8.Type) throws -> UInt8? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) and got \(value)"))
        }
        
        let uint8 = number.uint8Value
        guard NSNumber(value: uint8) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }
        
        return uint8
    }
    
    fileprivate func unbox(_ value: Any, as type: UInt16.Type) throws -> UInt16? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) and got \(value)"))
        }
        
        let uint16 = number.uint16Value
        guard NSNumber(value: uint16) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }
        
        return uint16
    }
    
    fileprivate func unbox(_ value: Any, as type: UInt32.Type) throws -> UInt32? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) and got \(value)"))
        }
        
        let uint32 = number.uint32Value
        guard NSNumber(value: uint32) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }
        
        return uint32
    }
    
    fileprivate func unbox(_ value: Any, as type: UInt64.Type) throws -> UInt64? {
        guard !(value is NSNull) else { return nil }
        
        guard let number = value as? NSNumber else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) and got \(value)"))
        }
        
        let uint64 = number.uint64Value
        guard NSNumber(value: uint64) == number else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed JSON number <\(number)> does not fit in \(type)."))
        }
        
        return uint64
    }
    
    fileprivate func unbox(_ value: Any, as type: Float.Type) throws -> Float? {
        guard !(value is NSNull) else { return nil }
        
        if let number = value as? NSNumber {
            // We are willing to return a Float by losing precision:
            // * If the original value was integral,
            //   * and the integral value was > Float.greatestFiniteMagnitude, we will fail
            //   * and the integral value was <= Float.greatestFiniteMagnitude, we are willing to lose precision past 2^24
            // * If it was a Float, you will get back the precise value
            // * If it was a Double or Decimal, you will get back the nearest approximation if it will fit
            let double = number.doubleValue
            guard abs(double) <= Double(Float.greatestFiniteMagnitude) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Parsed JSON number \(number) does not fit in \(type)."))
            }
            
            return Float(double)
            
            /* FIXME: If swift-corelibs-foundation doesn't change to use NSNumber, this code path will need to be included and tested:
             } else if let double = value as? Double {
             if abs(double) <= Double(Float.max) {
             return Float(double)
             }
             overflow = true
             } else if let int = value as? Int {
             if let float = Float(exactly: int) {
             return float
             }
             overflow = true
             */
            
        }

        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) but got \(value)"))
    }
    
    fileprivate func unbox(_ value: Any, as type: Double.Type) throws -> Double? {
        guard !(value is NSNull) else { return nil }
        
        if let number = value as? NSNumber {
            // We are always willing to return the number as a Double:
            // * If the original value was integral, it is guaranteed to fit in a Double; we are willing to lose precision past 2^53 if you encoded a UInt64 but requested a Double
            // * If it was a Float or Double, you will get back the precise value
            // * If it was Decimal, you will get back the nearest approximation
            return number.doubleValue
            
            /* FIXME: If swift-corelibs-foundation doesn't change to use NSNumber, this code path will need to be included and tested:
             } else if let double = value as? Double {
             return double
             } else if let int = value as? Int {
             if let double = Double(exactly: int) {
             return double
             }
             overflow = true
             */
            
        }
        
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) but got \(value)"))
    }
    
    fileprivate func unbox(_ value: Any, as type: String.Type) throws -> String? {
        guard !(value is NSNull) else { return nil }
        
        guard let string = value as? String else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) but got \(value)"))
        }
        
        return string
    }
    
    fileprivate func unbox(_ value: Any, as type: Date.Type) throws -> Date? {
        guard !(value is NSNull) else { return nil }
        
//        switch self.options.dateDecodingStrategy {
//        case .deferredToDate:
//            self.storage.push(container: value)
//            let date = try Date(from: self)
//            self.storage.popContainer()
//            return date
//
//        case .secondsSince1970:
//            let double = try self.unbox(value, as: Double.self)!
//            return Date(timeIntervalSince1970: double)
//
//        case .millisecondsSince1970:
//            let double = try self.unbox(value, as: Double.self)!
//            return Date(timeIntervalSince1970: double / 1000.0)
//
//        case .iso8601:
//            if #available(OSX 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
//                let string = try self.unbox(value, as: String.self)!
//                guard let date = _iso8601Formatter.date(from: string) else {
//                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected date string to be ISO8601-formatted."))
//                }
//
//                return date
//            } else {
//                fatalError("ISO8601DateFormatter is unavailable on this platform.")
//            }
//
//        case .formatted(let formatter):
//            let string = try self.unbox(value, as: String.self)!
//            guard let date = formatter.date(from: string) else {
//                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Date string does not match format expected by formatter."))
//            }
//
//            return date
//
//        case .custom(let closure):
//            self.storage.push(container: value)
//            let date = try closure(self)
//            self.storage.popContainer()
//            return date
//        }
        throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(type) but got \(value)"))

    }
    
    fileprivate func unbox(_ value: Any, as type: Data.Type) throws -> Data? {
        guard !(value is NSNull) else { return nil }
        
        guard let string = value as? String else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "\(type) but expected \(value)"))
        }
        
        guard let data = Data(base64Encoded: string) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Encountered Data is not valid Base64."))
        }
        
        return data
    }
    
    fileprivate func unbox(_ value: Any, as type: Decimal.Type) throws -> Decimal? {
        guard !(value is NSNull) else { return nil }
        
        // On Darwin we get (value as? Decimal) since JSONSerialization can produce NSDecimalNumber values.
        // FIXME: Attempt to grab a Decimal value if JSONSerialization on Linux produces one.
        let doubleValue = try self.unbox(value, as: Double.self)!
        return Decimal(doubleValue)
    }
    
    fileprivate func unbox<T : Decodable>(_ value: Any, as type: T.Type) throws -> T? {
        let decoded: T
        if T.self == Date.self {
            guard let date = try self.unbox(value, as: Date.self) else { return nil }
            decoded = date as! T
        } else if T.self == Data.self {
            guard let data = try self.unbox(value, as: Data.self) else { return nil }
            decoded = data as! T
        } else if T.self == URL.self {
            guard let urlString = try self.unbox(value, as: String.self) else {
                return nil
            }
            
            guard let url = URL(string: urlString) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath,
                                                                        debugDescription: "Invalid URL string."))
            }
            
            decoded = (url as! T)
        } else if T.self == Decimal.self {
            guard let decimal = try self.unbox(value, as: Decimal.self) else { return nil }
            decoded = decimal as! T
        } else {
            self.storage.push(container: value as! DecodeableNode)
            decoded = try T(from: self)
            self.storage.popContainer()
        }
        
        return decoded
    }
}



public extension HeterogenousAST where NodeType == HeterogeneousNode{
    subscript(child index:Int)->HeterogeneousNode?{
        if index < tokens.count {
            return tokens[index]
        }
        return nil
    }
}

public extension HeterogeneousNode{
    subscript(child token:Token)->HeterogeneousNode?{
        guard let children = value as? [HeterogeneousNode] else {
            return nil
        }
        
        for child in children{
            if child.token == token {
                return child
            }
        }
        
        return nil
    }
    
    
    subscript(child index:Int)->HeterogeneousNode?{
        guard let children = value as? [HeterogeneousNode] else {
            return nil
        }
        if index < children.count {
            return children[index]
        }
        return nil
    }
    
    var children : [HeterogeneousNode] {
        guard let children = value as? [HeterogeneousNode] else {
            return []
        }
        
        return children
    }
    
}