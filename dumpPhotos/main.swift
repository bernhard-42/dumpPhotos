//
//  main.swift
//  dumpPhotos
//
//  Created by Bernhard Walter on 03.06.16.
//  Copyright © 2016 Bernhard Walter. All rights reserved.
//

import Foundation
import Cocoa
import MediaLibrary

// 
// Helpers for KVO to keep context retained in async calls
//
func retained(str: String) -> UnsafeMutablePointer<Void> {
	return UnsafeMutablePointer<Void>(Unmanaged<NSString>.passRetained(str as NSString).toOpaque())
}

func released(ptr: UnsafeMutablePointer<Void>) -> String {
	return Unmanaged<NSString>.fromOpaque(COpaquePointer(ptr)).takeRetainedValue() as String
}

//
// JSON Helper
//
func JSONStringify(value: AnyObject, prettyPrinted:Bool = false) -> String {
	let options = prettyPrinted ? NSJSONWritingOptions.PrettyPrinted : NSJSONWritingOptions(rawValue: 0)
	if NSJSONSerialization.isValidJSONObject(value) {
		do {
			let data = try NSJSONSerialization.dataWithJSONObject(value, options: options)
			if let string = NSString(data: data, encoding: NSUTF8StringEncoding) {
				return string as String
			}
		} catch {
			print("error")
		}
	}
	return ""
}


//
// Result Classes
//

var allAttributes = [String: Int]()

class MediaObject {
	var identifier: String!
	var name: String!
	var url: String!
	var contentType: String!
	var attributes: [String : AnyObject]
	
	init(identifier: String, name: String = "", url: String = "", contentType: String = "", attributes: [String : AnyObject]) {
		self.identifier = identifier
		self.name = name
		self.url = url
		self.contentType = contentType
		self.attributes = attributes
	}
	
	func dict() -> [String: AnyObject] {
		var result:[String: AnyObject] = [:]
		for (key, value) in self.attributes {
			allAttributes[key] = 0
			let stringKeys:[String] = ["URL", "contentType", "originalURL", "resolutionString", "modificationDate", "keywordNamesAsString", "name", "Name", "Comment"]
			let rawKeys:[String] = ["longitude", "latitude", "modelId", "fileSize", "Hidden", "mediaType"]
			if (key == "ILMediaObjectKeywordsAttribute") {
				result["keywords"] = value as! [String]
			} else if (key == "Places") {
				result["places"] = value as! [String]
			} else if (key == "FaceList") {
				var faceNames = [String]()
				let faces  = value as! [AnyObject]
				for face in faces {
					let a = face as! [String: AnyObject]
					faceNames.append(a["name"] as! String)
				}
				result["faces"] = faceNames
				// result["faces"] = value as! [String]
			} else if (stringKeys.contains(key) ) {
				result[key] = "\(value)"
			} else if (rawKeys.contains(key) ) {
				result[key] = value
			} else if (key == "DateAsTimerInterval") {
				result["interval"] = value
			}
		}
//		if (name != "") { result["name"] = name as AnyObject }
//		if (url != "") { result["url"] = url as AnyObject }
//		if (contentType != "") { result["contentType"] = contentType as AnyObject }
		
		return result
	}
}

class Group {
	var identifier: String!
	var name: String!
	var type: String!
	var groups: [Group]!
	var mediaObjects: [String: MediaObject]!
	var mediaReferences: [String]!
	
	init(identifier: String, name: String, type: String) {
		self.identifier = identifier
		self.name = name
		self.type = type
	}
	
	func addGroup(group: Group) {
		if ( self.groups == nil) {
			self.groups = []
		}
		self.groups.append(group)
	}
	
	func addMediaObject(ident: String, mediaObject: MediaObject) {
		if (self.mediaObjects == nil) {
			self.mediaObjects = [ : ]
		}
		self.mediaObjects[ident] = mediaObject
	}
	
	func addMediaReference(ident: String) {
		if (self.mediaReferences == nil) {
			self.mediaReferences = []
		}
		self.mediaReferences.append(ident)
	}

	func dict() -> [String: AnyObject] {
		var result : [String: AnyObject] = ["identifier": identifier as AnyObject, "name": name as AnyObject, "type": type as AnyObject]
		if (groups != nil) {
			var g = [AnyObject]()
			for (group) in groups {
				g.append(group.dict() as AnyObject)
			}
			result["groups"] = g as AnyObject
		}
		if (mediaObjects != nil) {
			var m = [String: AnyObject]()
			for (ident, mediaObject) in mediaObjects {
				m[ident] = mediaObject.dict() as AnyObject
			}
			result["mediaObjects"] = m as AnyObject
		}
		if (mediaReferences != nil) {
			result["mediaReferences"] = mediaReferences as AnyObject
		}
		return result
	}
}

//
// The main class
//
class PhotosDump:NSObject {
	var library : MLMediaLibrary!
	var photos : MLMediaSource!
	var rootGroup : MLMediaGroup!
	var mediaObjects : [String: MLMediaGroup]!
	
	var groupList = [String: Group]()
	var groups = Group(identifier: "root", name: "Root Group", type: "com.apple.Photos.Folder")
	var albumCount = 0
	
	override init() {
		super.init()
		
		mediaObjects = [String: MLMediaGroup]()
		let options : [String : AnyObject] = [MLMediaLoadIncludeSourcesKey: [MLMediaSourcePhotosIdentifier]]
		library = MLMediaLibrary(options: options)
		library.addObserver(self, forKeyPath: "mediaSources", options: NSKeyValueObservingOptions.New, context: nil)
		library.mediaSources
		CFRunLoopRun();
	}
	
	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		guard let path = keyPath else { return }
		
		switch path {
		case "mediaSources":
			loadSources()
		case "rootMediaGroup":
			loadRootGroup()
		case "mediaObjects":
			loadMediaObjects(released(context))
		default:
			print("Nothing to do for \(path)")
		}
	}
	
	func loadSources(){
		if let mediaSources = library.mediaSources {
			for (_, source) in mediaSources {
				print("Source: \(source.mediaSourceIdentifier)")
				photos = source
				photos.addObserver(self, forKeyPath: "rootMediaGroup", options: NSKeyValueObservingOptions.New, context: nil)
				photos.rootMediaGroup
			}
		}
	}
	
	func traverseFolders(objects: MLMediaGroup, groups: Group) {
		for (album) in objects.childGroups! {
			let g = Group(identifier: album.identifier, name: album.name!, type: album.typeIdentifier)
			groups.addGroup(g)
			groupList[album.identifier] = g
			// print(album.name, album.identifier, album.typeIdentifier)
			if (album.identifier == "allPhotosAlbum" || album.typeIdentifier == "com.apple.Photos.Album") {
				// print("-", album.name)
				let context = album.identifier
				albumCount += 1
				mediaObjects[context] = album
				mediaObjects[context]?.addObserver(self, forKeyPath: "mediaObjects", options: NSKeyValueObservingOptions.New, context: retained(context))
				mediaObjects[context]?.mediaObjects
			} else if (album.typeIdentifier == "com.apple.Photos.Folder") {
				traverseFolders(album, groups:g)
			}
		}
	}
	
	func loadRootGroup(){
		if let rootGroup = photos.rootMediaGroup {
			print("Root Group: \(rootGroup.identifier):\(rootGroup.typeIdentifier)")
			if let albums = photos.mediaGroupForIdentifier("TopLevelAlbums") {
				traverseFolders(albums, groups: groups)
			}
		}
		
	}
	
	func loadMediaObjects(context: String) {
		if let mediaObjects = mediaObjects[context]?.mediaObjects {
			let group = groupList[context]
			var m: MediaObject!
			var count = 0
			for (mediaObject) in mediaObjects {
				if (context == "allPhotosAlbum") {
					let url = mediaObject.URL!
					let name = mediaObject.name ?? ""
					let contentType = mediaObject.contentType ?? ""
					let attributes = mediaObject.attributes
					m = MediaObject(identifier: mediaObject.identifier, name: name, url: url.absoluteString, attributes: attributes)
					group!.addMediaObject(mediaObject.identifier, mediaObject: m)
				} else {
					group!.addMediaReference(mediaObject.identifier)
				}
				
				count += 1
			}
			// print("==>", self.mediaObjects[context]?.name, count)
		}
		albumCount -= 1
		if (albumCount == 0) {
			let result = JSONStringify(groups.dict(), prettyPrinted: true)
			let fileManager = NSFileManager.defaultManager()
			let path = fileManager.currentDirectoryPath + "/PhotosLibrary.json"
			do {
				try result.writeToFile(path, atomically: true, encoding: NSUTF8StringEncoding)
				print(path)
			} catch {
				print("ERROR writing result")
			}
			print(allAttributes.keys)
			CFRunLoopStop(CFRunLoopGetCurrent())
		}
	}
}

let m = PhotosDump()
