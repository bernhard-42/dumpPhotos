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

class MediaObject {
	var identifier: String!
	var name: String!
	var url: String!
	var contentType: String!
	var attributes: [String : AnyObject]

    var mediaType: [UInt: String] = [MLMediaType.Audio.rawValue: "Audio",
                                     MLMediaType.Image.rawValue: "Image",
                                     MLMediaType.Movie.rawValue: "Movie"]
	
	let diffEpochToAppleTime = 978307200   // diff between 1.1.1970 (epoch) and 1.1.2001 (apple timer start)
    
    init(identifier: String, attributes: [String : AnyObject]) {
		self.identifier = identifier
		self.attributes = attributes
	}
	
	func dict() -> [String: AnyObject] {
		var result:[String: AnyObject] = [:]
		for (key, value) in self.attributes {

			switch (key) {
			case "ILMediaObjectKeywordsAttribute":
				result["keywords"] = value as! [String]
			
			case "Places":
				result["places"] = value as! [String]

			case "FaceList":
				var faceNames = [String]()
				let faces  = value as! [AnyObject]
				for face in faces {
					let a = face as! [String: AnyObject]
					faceNames.append(a["name"] as! String)
				}
				result["faces"] = faceNames
			
			case "contentType", "resolutionString", "keywordNamesAsString", "name":
				result[key] = "\(value)"
			
			case "URL", "originalURL", "thumbnailURL":
				let decodedUrl: String = "\(value)"
				result[key] = decodedUrl.stringByRemovingPercentEncoding!
			
			case "longitude", "latitude", "fileSize" /*, "modelId", "Hidden" */:
				result[key] = value
			
			case "DateAsTimerInterval":
				let seconds:Int = value as! Int
				result["eventDateAsTimerInterval"] = seconds
				result["eventDateAsEpochInterval"] = seconds + diffEpochToAppleTime
			
			case "modificationDate":
				let mDate:String = "\(value)"
				if mDate != "0000-12-30 00:00:00 +0000" {   // never modified
					result[key] = mDate
				}
			
			case "mediaType":
				result[key] = mediaType[value as! UInt]
			
			case "Comment":
				result["comment"] = "\(value)"
			
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
	var photosSource : MLMediaSource!
	var rootGroup : MLMediaGroup!
	var mediaObjects : [String: MLMediaGroup]!
	
	var groups = Group(identifier: "root", name: "Root Group", type: MLPhotosFolderTypeIdentifier)
    
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
	
    
    func loadLibrary() {
        mediaObjects = [String: MLMediaGroup]()
        
        // KVO: async load of media libraries
        library = MLMediaLibrary(options: [MLMediaLoadIncludeSourcesKey: [MLMediaSourcePhotosIdentifier]])
        library.addObserver(self, forKeyPath: "mediaSources", options: NSKeyValueObservingOptions.New, context: nil)
        library.mediaSources
    }
    
    
	func loadSources(){
		if let mediaSources = library.mediaSources {
			for (_, source) in mediaSources {
				print("Source: \(source.mediaSourceIdentifier)")
                
                // KVO: async load of root group of retrieved media source
				photosSource = source
				photosSource.addObserver(self, forKeyPath: "rootMediaGroup", options: NSKeyValueObservingOptions.New, context: nil)
				photosSource.rootMediaGroup
			}
		}
	}
	
    
    func loadRootGroup(){
        if let rootGroup = photosSource.rootMediaGroup {
            print("Scanning folder for Root Group: \"\(rootGroup.identifier):\(rootGroup.typeIdentifier)\"")
            
            if let albums = photosSource.mediaGroupForIdentifier(topLevelAlbumsIdentifier) {
                traverseFolders(albums, groups: groups)
            }
        }
    }
    
	func traverseFolders(objects: MLMediaGroup, groups: Group) {
		for (album) in objects.childGroups! {

            // add a new group
            let g = Group(identifier: album.identifier, name: album.name!, type: album.typeIdentifier)

            if (album.typeIdentifier == MLPhotosFolderTypeIdentifier) {
				groups.addGroup(g)
				traverseFolders(album, groups:g)
			} else {
                if !ignoreAlbumIdentifiers.contains(album.identifier) {
					groups.addGroup(g)
                    let context = album.identifier
                    albumList[context] = g   // make group acessible via context to insert media objects in function loadMediaObjects
                    albumLoadCounter += 1
                    
                    // KVO: async load of media objects (photos and videos)
                    mediaObjects[context] = album   // make album acessible via context in function loadMediaObjects
                    mediaObjects[context]!.addObserver(self, forKeyPath: "mediaObjects", options: NSKeyValueObservingOptions.New, context: retained(context))
                    mediaObjects[context]!.mediaObjects
                }
			}
		}
	}
	
	func loadMediaObjects(context: String) {
        if let mediaObjs = mediaObjects[context]!.mediaObjects {
            let album = albumList[context]
            var m: MediaObject
            var count = 0
            for (mediaObject) in mediaObjs {
                if (context == allPhotosAlbumIdentifier) {
                    let attributes = mediaObject.attributes
                    m = MediaObject(identifier: mediaObject.identifier, attributes: attributes)
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
                let fileManager = NSFileManager.defaultManager()
                let path = fileManager.currentDirectoryPath + "/PhotosLibrary.json"
                do {
                    try result.writeToFile(path, atomically: true, encoding: NSUTF8StringEncoding)
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
