//
//  Asset.swift
//  RNTrackPlayer
//
//  Created by Kateryna Peikova on 23.03.2022.
//  Copyright © 2022 David Chavez. All rights reserved.
//

import AVFoundation

public class Asset {
    
    /// The AVURLAsset corresponding to this Asset.
    var urlAsset: AVURLAsset
    
    let name: String
    
    public init(name: String, urlAsset: AVURLAsset) {
        self.urlAsset = urlAsset
        self.name = name
    }
}

/// Extends `Asset` to conform to the `Equatable` protocol.
extension Asset: Equatable {
    public static func ==(lhs: Asset, rhs: Asset) -> Bool {
        return (lhs.name == rhs.name) && (lhs.urlAsset == rhs.urlAsset)
    }
}

/**
 Extends `Asset` to add a simple download state enumeration used by the sample
 to track the download states of Assets.
 */
extension Asset {
    enum DownloadState: String {
        
        /// The asset is not downloaded at all.
        case notDownloaded
        
        /// The asset has a download in progress.
        case downloading
        
        /// The asset is downloaded and saved on diek.
        case downloaded
    }
}

/**
 Extends `Asset` to define a number of values to use as keys in dictionary lookups.
 */
extension Asset {
    struct Keys {
        /**
         Key for the Asset name, used for `AssetDownloadProgressNotification` and
         `AssetDownloadStateChangedNotification` Notifications as well as
         AssetListManager.
         */
        static let name = "AssetNameKey"

        /**
         Key for the Asset download percentage, used for
         `AssetDownloadProgressNotification` Notification.
         */
        static let percentDownloaded = "AssetPercentDownloadedKey"

        /**
         Key for the Asset download state, used for
         `AssetDownloadStateChangedNotification` Notification.
         */
        static let downloadState = "AssetDownloadStateKey"

        /**
         Key for the Asset download AVMediaSelection display Name, used for
         `AssetDownloadStateChangedNotification` Notification.
         */
        static let downloadSelectionDisplayName = "AssetDownloadSelectionDisplayNameKey"
    }
}
