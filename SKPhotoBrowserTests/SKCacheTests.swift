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
    var image: UIImage!
    let key = "test_image"
    let data = Data([0x01, 0x02, 0x03])

    override func setUp() {
        super.setUp()

        self.cache = SKCache()
        self.image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        self.cache.removeAllImages()
        self.cache.removeAllData()
    }

    override func tearDown() {
        self.cache.removeAllImages()
        self.cache.removeAllData()
        self.image = nil
        self.cache = nil

        super.tearDown()
    }
    
    func testInit() {
        XCTAssertNotNil(self.cache.imageCache)
        XCTAssert(self.cache.imageCache is SKDefaultImageCache, "Default image cache should be loaded on init")
    }

    func testDefaultCacheImageForKey() {
        // given
        self.cache.setImage(self.image, forKey: self.key)

        // when
        let cachedImage = self.cache.imageForKey(self.key)

        // then
        XCTAssertNotNil(cachedImage)
    }

    func testDefaultCacheSetImageForKey() {
        // when
        self.cache.setImage(self.image, forKey: self.key)

        // then
        let cachedImage = self.cache.imageForKey(self.key)
        XCTAssertNotNil(cachedImage)
    }

    func testDefaultCacheRemoveImageForKey() {
        // given
        self.cache.setImage(self.image, forKey: self.key)

        // when
        self.cache.removeImageForKey(self.key)

        // then
        let cachedImage = self.cache.imageForKey(self.key)
        XCTAssertNil(cachedImage)
    }
    
    func testDefaultCacheRemoveAllImages() {
        // given
        self.cache.setImage(self.image, forKey: self.key)
        
        let anotherImage = self.image!
        let anotherKey = "another_test_image"
        self.cache.setImage(anotherImage, forKey: anotherKey)
        
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
        self.cache.setData(self.data, forKey: self.key)

        // when
        let cachedData = self.cache.dataForKey(self.key)

        // then
        XCTAssertEqual(cachedData, self.data)
    }

    func testDefaultCacheSetDataForKey() {
        // when
        self.cache.setData(self.data, forKey: self.key)

        // then
        let cachedData = self.cache.dataForKey(self.key)
        XCTAssertEqual(cachedData, self.data)
    }

    func testDefaultCacheRemoveDataForKey() {
        // given
        self.cache.setData(self.data, forKey: self.key)

        // when
        self.cache.removeDataForKey(self.key)

        // then
        XCTAssertNil(self.cache.dataForKey(self.key))
    }

    func testDefaultCacheRemoveAllData() {
        // given
        self.cache.setData(self.data, forKey: self.key)
        self.cache.setData(Data([0x04]), forKey: "another_test_data")

        // when
        self.cache.removeAllData()

        // then
        XCTAssertNil(self.cache.dataForKey(self.key))
        XCTAssertNil(self.cache.dataForKey("another_test_data"))
    }

    func testDefaultCachePersistsDataAcrossInstances() {
        // given
        self.cache.setData(self.data, forKey: self.key)
        let anotherCache = SKCache()

        // when
        let cachedData = anotherCache.dataForKey(self.key)

        // then
        XCTAssertEqual(cachedData, self.data)
    }

    func testDefaultCacheRequestResponseData() {
        // given
        let url = URL(string: "https://example.com/image.png")!
        let request = URLRequest(url: url)
        let response = URLResponse(url: url, mimeType: "image/png", expectedContentLength: data.count, textEncodingName: nil)

        // when
        self.cache.setImageData(data, response: response, request: request)

        // then
        XCTAssertEqual(self.cache.dataForRequest(request), data)
    }
}
