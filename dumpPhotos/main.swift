//
//  main.swift
//  dumpPhotos
//
//  Created by Bernhard Walter on 03.06.2016
//  Ported to Swift 3 on 25.09.2016
//
//  Copyright © 2016 Bernhard Walter. All rights reserved.
//

import Foundation
import Cocoa
import MediaLibrary

// 
// Helpers for KVO to keep context retained in async calls
//
func retained(_ str: String) -> UnsafeMutableRawPointer {
	return UnsafeMutableRawPointer(Unmanaged<NSString>.passRetained(str as NSString).toOpaque())
}

func released(_ ptr: UnsafeMutableRawPointer) -> String {
    return Unmanaged<NSString>.fromOpaque(UnsafeRawPointer(ptr)).takeRetainedValue() as String
}


//
// Helpers to force single byte unicode utf-8 characters
//

func precomp(_ str: String) -> String {
	return str.precomposedStringWithCanonicalMapping
}

func precompArray(_ arr: [String]) -> [String] {
	var result = [String]()
	for str in arr {
		result.append(str)
	}
	return result
}


//
// JSON Helper
//
func JSONStringify(_ value: Any, prettyPrinted:Bool = false) -> String {
	let options = prettyPrinted ? JSONSerialization.WritingOptions.prettyPrinted : JSONSerialization.WritingOptions(rawValue: 0)
	if JSONSerialization.isValidJSONObject(value) {
		do {
			let data = try JSONSerialization.data(withJSONObject: value, options: options)
			if let str = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
				return str as String
			}
		} catch {
			print("error: conversion failed")
            return ""
		}
	}
    print("error: invalid dict")
	return ""
}


//
// diff between 1.1.1970 (epoch) and 1.1.2001 (apple timer reference)
//
// let now = NSDate()
// let diffEpochToAppleTime = Int(now.timeIntervalSince1970 - now.timeIntervalSinceReferenceDate)
//
let diffEpochToAppleTime = 978307200


//
// Result Classes
//

class MediaObject {
	var identifier: String!
	var name: String!
	var url: String!
	var contentType: String!
	var attributes: [String : Any]

    var mediaType: [UInt: String] = [MLMediaType.audio.rawValue: "Audio",
                                     MLMediaType.image.rawValue: "Image",
                                     MLMediaType.movie.rawValue: "Movie"]
	
	
    init(identifier: String, attributes: [String: Any]) {
		self.identifier = identifier
		self.attributes = attributes
	}
	
	func dict() -> [String: Any] {
		var result = [String: Any]()
		for (key, value) in self.attributes {

			switch (key) {
			case "ILMediaObjectKeywordsAttribute":
				let keywords = value as! [String]
				result["keywords"] = precompArray(keywords)
			
			case "Places":
				let places = value as! [String]
				result["places"] = precompArray(places)

			case "FaceList":
				var faceNames = [String]()
				let faces  = value as! [AnyObject]
                for face in faces {
					faceNames.append(precomp(face["name"] as! String))
				}
				result["faces"] = faceNames
			
			case "contentType", "resolutionString", "keywordNamesAsString", "name":
				result[key] = precomp(value as! String)
			
			case "URL", "originalURL", "thumbnailURL":
				let url = value as! URL
				result[key] = precomp(url.absoluteString.removingPercentEncoding!)
			
			case "longitude", "latitude", "fileSize" /*, "modelId", "Hidden" */:
				result[key] = value
			
			case "DateAsTimerInterval":
				let seconds:Int = value as! Int
				result["eventDate"] = seconds + diffEpochToAppleTime
			
			case "modificationDate":
				let mDate:Date = value as! Date
                if (mDate > Date.distantPast) {
					result["modificationDate"] = Int(mDate.timeIntervalSince1970)
				}
			
			case "mediaType":
				result[key] = mediaType[value as! UInt]
			
			case "Comment":
				result["comment"] = precomp(value as! String)
			
			default:
				()
			}
		}

        return result
	}
}

class Group {
	var identifier: String!
	var name: String!
	var type: String!
	
	var groups = [Group]()
	var mediaObjects = [String: MediaObject]()
	var mediaReferences = [String]()
	
	init(identifier: String, name: String, type: String) {
		self.identifier = identifier
		self.name = name
		self.type = type
	}
	
	func addGroup(_ group: Group) {
		self.groups.append(group)
	}
	
	func addMediaObject(_ ident: String, mediaObject: MediaObject) {
		self.mediaObjects[ident] = mediaObject
	}
	
	func addMediaReference(_ ident: String) {
		self.mediaReferences.append(ident)
	}

	func dict() -> [String: Any] {
		var result : [String: Any] = ["identifier": identifier, "name": name, "type": type]
		if (groups.count > 0) {
			var g = [Any]()
			for (group) in groups {
				g.append(group.dict() as Any)
			}
			result["groups"] = g
		}
		
		if (mediaObjects.count > 0) {
			var m = [String: Any]()
			for (ident, mediaObject) in mediaObjects {
				m[ident] = mediaObject.dict() as Any
			}
			result["mediaObjects"] = m as Any
		}
		
		if (mediaReferences.count > 0) {
			result["mediaReferences"] = mediaReferences as Any
		}
		return result
	}
}


//
// The main class
//
class PhotosDump:NSObject {
	var library : MLMediaLibrary!
	var photosSource : MLMediaSource!
	var rootGroup : MLMediaGroup!
	
	var groups = Group(identifier: "root", name: "Root Group", type: MLPhotosFolderTypeIdentifier)
	var mediaObjects  = [String: MLMediaGroup]()
	
    var albumList = [String: Group]()
	var albumLoadCounter = 0
	
	// Cocoa constants not found in MediaLibrary
	let topLevelAlbumsIdentifier = "TopLevelAlbums"
	let allPhotosAlbumIdentifier = "allPhotosAlbum"
	let ignoreAlbumIdentifiers : [String] = ["lastImportAlbum", "photoStreamAlbum", "peopleAlbum"]
	
	
	override init() {
		super.init()
		loadLibrary()
		CFRunLoopRun();
	}
	
    
	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		guard let path = keyPath else { return }
		
		switch path {
		case "mediaSources":
			loadSources()
		case "rootMediaGroup":
			loadRootGroup()
		case "mediaObjects":
			loadMediaObjects(released(context!))
		default:
			print("Nothing to do for \(path)")
		}
	}
	
    
    func loadLibrary() {
        // KVO: async load of media libraries
        library = MLMediaLibrary(options: [MLMediaLoadIncludeSourcesKey: [MLMediaSourcePhotosIdentifier]])
        library.addObserver(self, forKeyPath: "mediaSources", options: NSKeyValueObservingOptions.new, context: nil)
        _ = library.mediaSources
    }
    
    
	func loadSources(){
		if let mediaSources = library.mediaSources {
			for (_, source) in mediaSources {
				print("Source: \(source.mediaSourceIdentifier)")
                
                // KVO: async load of root group of retrieved media source
				photosSource = source
				photosSource.addObserver(self, forKeyPath: "rootMediaGroup", options: NSKeyValueObservingOptions.new, context: nil)
				_ = photosSource.rootMediaGroup
			}
		}
	}
	
    
    func loadRootGroup(){
        if let rootGroup = photosSource.rootMediaGroup {
            print("Scanning folder for Root Group: \"\(rootGroup.identifier):\(rootGroup.typeIdentifier)\"")
            
            if let albums = photosSource.mediaGroup(forIdentifier: topLevelAlbumsIdentifier) {
                traverseFolders(albums, groups: groups)
            }
        }
    }
    
	func traverseFolders(_ objects: MLMediaGroup, groups: Group) {
		for (album) in objects.childGroups! {
			if !ignoreAlbumIdentifiers.contains(album.identifier) {

				// add a new group
				let g = Group(identifier: album.identifier, name: album.name!, type: album.typeIdentifier)
				groups.addGroup(g)

				if (album.typeIdentifier == MLPhotosFolderTypeIdentifier) {
					traverseFolders(album, groups:g)
				} else {
					let context = album.identifier
					albumList[context] = g   // make group acessible via context to insert media objects in function loadMediaObjects
					albumLoadCounter += 1
					
					// KVO: async load of media objects (photos and videos)
					mediaObjects[context] = album   // make album acessible via context in function loadMediaObjects
					mediaObjects[context]!.addObserver(self, forKeyPath: "mediaObjects", options: NSKeyValueObservingOptions.new, context: retained(context))
					_ = mediaObjects[context]!.mediaObjects
				}
			}
		}
	}
	
	func loadMediaObjects(_ context: String) {
        if let mediaObjs = mediaObjects[context]!.mediaObjects {
            let album = albumList[context]
            var m: MediaObject
            var count = 0
            for (mediaObject) in mediaObjs {
                if (context == allPhotosAlbumIdentifier) {
                    let attributes = mediaObject.attributes
                    m = MediaObject(identifier: mediaObject.identifier, attributes: attributes as [String : Any])
					groups.addMediaObject(mediaObject.identifier, mediaObject: m)
				}
				album!.addMediaReference(mediaObject.identifier)
                count += 1
            }
            print("- Album \"\(self.mediaObjects[context]!.name!)\": \(count) media objects")
            albumLoadCounter -= 1
            
            // if all groups are loaded asynronously, convert constructed groups class to JSON
            if (albumLoadCounter == 0) {
                print("Converting to JSON")
                let result = JSONStringify(groups.dict(), prettyPrinted: true)
                print("Writing result")
                let fileManager = FileManager.default
                let path = fileManager.currentDirectoryPath + "/PhotosLibrary.json"
                do {
                    try result.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
                    print(path)
                } catch {
                    print("ERROR writing result")
                }
                CFRunLoopStop(CFRunLoopGetCurrent())
            }
        }
	}
}

let m = PhotosDump()
