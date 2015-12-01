//
//  Index.swift
//  Geomsaek
//
//  Copyright © 2015 Nate Cook. All rights reserved.
//

import Foundation

public enum IndexType: Int {
    case Unknown         = 0
    case Inverted        = 1
    case Vector          = 2
    case InvertedVector  = 3
   
    private var _skIndexType: SKIndexType {
        return SKIndexType(rawValue: UInt32(self.rawValue))
    }
}

public class Index {
    internal let _index: SKIndexRef
    
    public init(name: String? = nil, type: IndexType = .Inverted, properties: [NSObject: AnyObject] = [:]) {
        let mutableData = NSMutableData()
        self._index = SKIndexCreateWithMutableData(mutableData, name, type._skIndexType, properties).takeRetainedValue()
    }
    
    public init(mutableData: NSMutableData, name: String? = nil, type: IndexType = .Inverted, properties: [NSObject: AnyObject] = [:]) {
        if let index = SKIndexOpenWithMutableData(mutableData, name) {
            self._index = index.takeRetainedValue()
        } else {
            self._index = SKIndexCreateWithMutableData(mutableData, name, type._skIndexType, properties).takeRetainedValue()
        }
    }
    
    public init(url: NSURL, name: String? = nil, type: IndexType = .Inverted, properties: [NSObject: AnyObject] = [:]) {
        if let index = SKIndexOpenWithURL(url, name, true) {
            self._index = index.takeRetainedValue()
        } else {
            self._index = SKIndexCreateWithURL(url, name, type._skIndexType, properties).takeRetainedValue()
        }
    }
    
    public func add(document: Document, withText text: String, replacing: Bool = true) {
        SKIndexAddDocumentWithText(_index, document._doc, text, replacing)
    }
    
    public func add(document: Document, withMimeHint hint: String? = nil, replacing: Bool = true) {
        SKIndexAddDocument(_index, document._doc, hint, replacing)
    }
    
    public func flushIndex() {
        SKIndexFlush(_index)
    }
    
    internal func documentsWithIDs(var documentIDs: [DocumentID]) -> [Document?] {
        var unmanagedDocuments: [Unmanaged<SKDocumentRef>?] = Array(count: documentIDs.count, repeatedValue: nil)
        
        SKIndexCopyDocumentRefsForDocumentIDs(_index, documentIDs.count, &documentIDs, &unmanagedDocuments)
        return unmanagedDocuments.map({
            guard let skdoc = $0?.takeRetainedValue() else { return nil }
            return Document(_skdoc: skdoc)
        })
    }
    
    internal func urlsWithIDs(var documentIDs: [DocumentID]) -> [NSURL?] {
        // unmanagedURLs will get populated with CFURL objects from the array of document IDs
        var unmanagedURLs: [Unmanaged<CFURL>?] = Array(count: documentIDs.count, repeatedValue: nil)
        SKIndexCopyDocumentURLsForDocumentIDs(_index, documentIDs.count, &documentIDs, &unmanagedURLs)
        
        // take the retained value of each url, then convert from CFURL? to NSURL?
        return unmanagedURLs.map({ $0?.takeRetainedValue() as NSURL? })
    }
    
    public var documentCount: Int {
        return SKIndexGetDocumentCount(_index)
    }
}

