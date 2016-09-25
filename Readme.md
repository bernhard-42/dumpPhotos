
A little command line tool to dump the Media Library of "Photos for Mac" to a JSON file.

Calling
    
    dumpPhotos

will create the file `PhotosLibrary.json`

Structure:

    {
        "identifier" : "root",
        "name" : "Root Group",
        "type" : "com.apple.Photos.Folder",
        "groups" : [
            {
                "name" : "Alle Fotos",
                "mediaReferences" : [
                    "i7k%1FZqSFuZ3%xIu4bdTg",
                    "REx1nlmyQVazwRSkUanZFA",
                    "mSts941eR0y9MTwUzXNfQw",
                    "hkS9YRMTRh2S1Qh4VW1+oQ",
                    ...
                ],
                "type" : "com.apple.Photos.AllPhotosAlbum",
                "identifier" : "allPhotosAlbum"
            },
            {
                "name" : "Selfies",
                "mediaReferences" : [
                    "GJygFR+DSHyDUArpZKSP3w",
                    "JN54dcdOSsiX0rJqYXBsWg",
                    ...
                ],
                "type" : "com.apple.Photos.FrontCameraGroup",
                "identifier" : "iPhoneFrontCameraAlbum"
            },
            {
                "name" : "Panoramen",
                "mediaReferences" : [
                    "XMnFzrqYSHmN4N1Lhk3r+Q",
                    "cQY1nPoUQxe5rRAjLQEVdA",
                    ...
                ],
                "type" : "com.apple.Photos.PanoramasGroup",
                "identifier" : "panoramaAlbum"
            },
            {
                "name" : "Videos",
                "mediaReferences" : [
                    "8i%qB3OgRLKeD1KvYHv+FA",
                    "vSZittp%QfiW9cqmC%MX+w",
                    ...
                ],
                "type" : "com.apple.Photos.VideosGroup",
                "identifier" : "videoAlbum"
            },
            {
                "name" : "Markiert",
                "mediaReferences" : [
                    "0rlJBtwbQYyOrVoXlVnHeg",
                    "m7W0YA0AQHq5gIkm7VTNqw",
                    ...
                ],
                "type" : "com.apple.Photos.SmartAlbum",
                "identifier" : "AkYpd4jmQi2AtceI7onbrw"
            },
            {
                "name" : "iPhoto-Ereignisse",
                "groups" : [
                    {
                        "name" : "2016 Saalfelden",
                        "mediaReferences" : [
                            "i7k%1FZqSFuZ3%xIu4bdTg",
                            "REx1nlmyQVazwRSkUanZFA",
                            ...
                        ],
                        "type" : "com.apple.Photos.Album",
                        "identifier" : "duHPP2KISqGtwmizqRxyGQ"
                    },
                    ...
                ],
                "type" : "com.apple.Photos.Folder",
                "identifier" : "dEY092TdT32N2ILI5jJeJg"
            }
        },
        "mediaObjects" : {
            "i7k%1FZqSFuZ3%xIu4bdTg" : {
                "latitude" : 47.42642975,
                "resolutionString" : "{4416, 3312}",
                "contentType" : "public.jpeg",
                "URL" : "file:\/\/\/Users\/Shared\/Fotos Library.photoslibrary\//Masters\/2016\/08\/29\/20160829-212044\/IMG_1001.JPG",
                "places" : [
                    "Saalfelden am Steinernen Meer",
                    "Salzburg",
                    "Österreich"
                ],
                "longitude" : 12.84917737,
                "eventDate" : 1251466509,
                "originalURL" : "file:\/\/\/Users\/Shared\/Fotos Library.photoslibrary\/2016\/08\/29\/20160829-212044\/IMG_1001.JPG",
                "mediaType" : "Image",
                "thumbnailURL" : "file:\/\/\/Users\/Shared\/Fotos Library.photoslibrary\/Thumbnails\/2016\/08\/29\/20160829-212044\/IMG_1001.jpg",
                "fileSize" : 5963538
            },
            "REx1nlmyQVazwRSkUanZFA" : {
                "latitude" : 47.42642975,
                "resolutionString" : "{3312, 4416}",
                "contentType" : "public.jpeg",
                "URL" : "file:\/\/\/Users\/Shared\/Fotos Library.photoslibrary\//Masters\/2016\/08\/29\/20160829-212830\/IMG_1002.JPG",
                "places" : [
                    "Saalfelden am Steinernen Meer",
                    "Salzburg",
                    "Österreich"
                ],
                "longitude" : 12.84917737,
                "eventDate" : 1251466528,
                "originalURL" : "file:\/\/\/Users\/Shared\/Fotos Library.photoslibrary\/2016\/08\/29\/20160829-212830\/IMG_1002.JPG",
                "mediaType" : "Image",
                "thumbnailURL" : "file:\/\/\/Users\/Shared\/Fotos Library.photoslibrary\/Thumbnails\/2016\/08\/29\/20160829-212830\/IMG_1002.jpg",
                "fileSize" : 7300680
            },
            ...    
        }
    }
