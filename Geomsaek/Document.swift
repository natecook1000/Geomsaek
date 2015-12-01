//
//  Document.swift
//  Geomsaek
//
//  Copyright © 2015 Nate Cook. All rights reserved.
//

import Foundation

public typealias DocumentID = SKDocumentID

public struct Document {
    internal let _doc: SKDocumentRef

    public var url: NSURL {
        return SKDocumentCopyURL(_doc).takeRetainedValue() as NSURL
    }

    public init(url: NSURL) {
        self._doc = SKDocumentCreateWithURL(url as CFURL).takeRetainedValue()
    }
    
    internal init(_skdoc: SKDocumentRef) {
        self._doc = _skdoc
    }
}

