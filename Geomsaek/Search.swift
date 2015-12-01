//
//  Search.swift
//  Geomsaek
//
//  Copyright © 2015 Nate Cook. All rights reserved.
//

import Foundation

public enum SearchOptions: UInt32 {
   case Default             = 0b000
   case NoRelevanceScores   = 0b001
   case SpaceMeansOR        = 0b010
   case FindSimilar         = 0b100
}

private let _searchQueue = NSOperationQueue()

private class _SearchOperation: NSOperation {
    let search: SKSearchRef
    var results: [DocumentID] = []
    var resultScores: [Float] = []
    var shouldCancel = false
    var progressBlock: (([SKDocumentID], [Float]) -> Void)?
    
    override func main() {
        super.main()
        
        var moreResults = true
        let limit = 20
        
        while moreResults && !shouldCancel {
            var found: CFIndex = 0
            var documentIDs: [SKDocumentID] = Array(count: limit, repeatedValue: 0)
            var scores: [Float] = Array(count: limit, repeatedValue: 0)
            
            moreResults = SKSearchFindMatches(search, limit, &documentIDs, &scores, 1000, &found)
            
            // append only the found results
            results.appendContentsOf(documentIDs[0 ..< found])
            resultScores.appendContentsOf(scores[0 ..< found])
            
            // call progress block
            progressBlock?(results, resultScores)
        }
    }
    
    init(search: SKSearchRef) {
        self.search = search
    }
}

public class Searcher {
    public typealias SearchID = Int
    public typealias SearchResultsHandler = (SearchResults) -> Void

    private let _index: Index
    private let _options: SKSearchOptions

    private var _nextSearchID = 0
    private var _searches: [SearchID: _SearchOperation] = [:]
    
    public init(inIndex index: Index, options: SearchOptions = .Default) {
        self._index = index
        self._options = options.rawValue
    }
    
    public func startSearch(terms: String, progressHandler: SearchResultsHandler? = nil, completionHandler: SearchResultsHandler?) -> SearchID {
        // create a search and a new unique search ID
        let search = SKSearchCreate(_index._index, terms, _options).takeRetainedValue()
        let searchID = _nextSearchID++

        // create a search operation to run the search on the `searchQueue` operations queue
        let searchOperation = _SearchOperation(search: search)
        
        // we only need to add a progress handler to the operation if we have one to call
        if let progressHandler = progressHandler {
            searchOperation.progressBlock = { resultsBatch, scoresBatch in
                let results = SearchResults(index: self._index, documentIDs: resultsBatch, scores: scoresBatch)
                progressHandler(results)
            }
        }
        
        // but we need the completion block either way, since it clears the operation and 
        // consquently the SKSearchRef object from the dictionary
        searchOperation.completionBlock = {
            if let completionHandler = completionHandler {
                let results = SearchResults(index: self._index, documentIDs: searchOperation.results, scores: searchOperation.resultScores)
                completionHandler(results)
            }
            self._searches[searchID] = nil
        }

        // save the operation in our dictionary so we can cancel it using the search ID,
        // then add it to the search queue to kick off returning the results
        _searches[searchID] = searchOperation
        _searchQueue.addOperation(searchOperation)

        return searchID
    }
    
    public func cancelSearch(searchID: SearchID) {
        if let operation = _searches[searchID] {
            operation.shouldCancel = true
            SKSearchCancel(operation.search)
        }
    }
    
    public func cancelAllSearches() {
        _searches.keys.forEach(cancelSearch)
    }
}

public class SearchResults {
    internal let _index: Index
    public let documentIDs: [DocumentID]
    public let scores: [Float]
    
    internal var _documents: [Document]?
    public var documents: [Document] {
        if _documents == nil {
            _documents = _index.documentsWithIDs(documentIDs).flatMap({ $0 })
        }
        return _documents!
    }
    
    internal var _urls: [NSURL]?
    public var urls: [NSURL] {
        if _urls == nil {
            _urls = _index.urlsWithIDs(documentIDs).flatMap({ $0 })
        }
        return _urls!
    }
    
    init(index: Index, documentIDs: [DocumentID], scores: [Float]) {
        self._index = index
        self.documentIDs = documentIDs
        self.scores = scores
    }
}

