//
//  SKCacheTests.swift
//  SKPhotoBrowser
//
//  Created by Kevin Wolkober on 6/13/16.
//  Copyright © 2016 suzuki_keishi. All rights reserved.
//

import XCTest
@testable import SKPhotoBrowser

class SKCacheTests: XCTestCase {

    var cache: SKCache!
    let image = UIImage()
    let key = "test_image"
    let data = Data([0x01, 0x02, 0x03])

    override func setUp() {
        super.setUp()

        self.cache = SKCache()
    }

    override func tearDown() {
        self.cache = nil

        super.tearDown()
    }
    
    func testInit() {
        XCTAssertNotNil(self.cache.imageCache)
        XCTAssert(self.cache.imageCache is SKDefaultImageCache, "Default image cache should be loaded on init")
    }

    func testDefaultCacheImageForKey() {
        // given
        let cache = (self.cache.imageCache as? SKDefaultImageCache)!.cache
        cache.setObject(self.image, forKey: self.key as AnyObject)

        // when
        let cachedImage = self.cache.imageForKey(self.key)

        // then
        XCTAssertNotNil(cachedImage)
    }

    func testDefaultCacheSetImageForKey() {
        // when
        self.cache.setImage(self.image, forKey: self.key)

        // then
        let cache = (self.cache.imageCache as? SKDefaultImageCache)!.cache
        let cachedImage = cache.object(forKey: self.key as AnyObject) as? UIImage
        XCTAssertNotNil(cachedImage)
    }

    func testDefaultCacheRemoveImageForKey() {
        // given
        let cache = (self.cache.imageCache as? SKDefaultImageCache)!.cache
        cache.setObject(self.image, forKey: self.key as AnyObject)

        // when
        self.cache.removeImageForKey(self.key)

        // then
        let cachedImage = self.cache.imageForKey(self.key)
        XCTAssertNil(cachedImage)
    }
    
    func testDefaultCacheRemoveAllImages() {
        // given
        let cache = (self.cache.imageCache as? SKDefaultImageCache)!.cache
        cache.setObject(self.image, forKey: self.key as AnyObject)
        
        let anotherImage = UIImage()
        let anotherKey = "another_test_image"
        cache.setObject(anotherImage, forKey: anotherKey as AnyObject)
        
        // when
        self.cache.removeAllImages()
        
        // then
        let cachedImage = self.cache.imageForKey(self.key)
        let anotherCachedImage = self.cache.imageForKey(anotherKey)
        XCTAssertNil(cachedImage)
        XCTAssertNil(anotherCachedImage)
    }

    func testDefaultCacheDataForKey() {
        // given
        let cache = (self.cache.imageCache as? SKDefaultImageCache)!.dataCache
        cache.setObject(self.data as AnyObject, forKey: self.key as AnyObject)

        // when
        let cachedData = self.cache.dataForKey(self.key)

        // then
        XCTAssertEqual(cachedData, self.data)
    }

    func testDefaultCacheSetDataForKey() {
        // when
        self.cache.setData(self.data, forKey: self.key)

        // then
        let cache = (self.cache.imageCache as? SKDefaultImageCache)!.dataCache
        let cachedData = cache.object(forKey: self.key as AnyObject) as? Data
        XCTAssertEqual(cachedData, self.data)
    }

    func testDefaultCacheRemoveDataForKey() {
        // given
        let cache = (self.cache.imageCache as? SKDefaultImageCache)!.dataCache
        cache.setObject(self.data as AnyObject, forKey: self.key as AnyObject)

        // when
        self.cache.removeDataForKey(self.key)

        // then
        XCTAssertNil(self.cache.dataForKey(self.key))
    }

    func testDefaultCacheRemoveAllData() {
        // given
        let cache = (self.cache.imageCache as? SKDefaultImageCache)!.dataCache
        cache.setObject(self.data as AnyObject, forKey: self.key as AnyObject)
        cache.setObject(Data([0x04]) as AnyObject, forKey: "another_test_data" as AnyObject)

        // when
        self.cache.removeAllData()

        // then
        XCTAssertNil(self.cache.dataForKey(self.key))
        XCTAssertNil(self.cache.dataForKey("another_test_data"))
    }
}
