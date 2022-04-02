//
//  AssetPersistenceManager.swift
//  RNTrackPlayer
//
//  Created by Kateryna Peikova on 23.03.2022.
//  Copyright © 2022 David Chavez. All rights reserved.
//

import Foundation
import AVFoundation

/// - Tag: AssetPersistenceManager
public class AssetPersistenceManager: NSObject {
    // MARK: Properties

    /// Singleton for AssetPersistenceManager.
    public static let sharedManager = AssetPersistenceManager()

    /// Internal Bool used to track if the AssetPersistenceManager finished restoring its state.
    private var didRestorePersistenceManager = false

    /// The AVAssetDownloadURLSession to use for managing AVAssetDownloadTasks.
    public var assetDownloadURLSession: AVAssetDownloadURLSession!

    /// Internal map of AVAggregateAssetDownloadTask to its corresponding Asset.
    fileprivate var activeDownloadsMap = [AVAssetDownloadTask: Asset]()

    // MARK: Intialization

    override private init() {

        super.init()

        // Create the configuration for the AVAssetDownloadURLSession.
        let backgroundConfiguration = URLSessionConfiguration.background(withIdentifier: "AAPL-Identifier")

        // Create the AVAssetDownloadURLSession using the configuration.
        assetDownloadURLSession =
            AVAssetDownloadURLSession(configuration: backgroundConfiguration,
                                      assetDownloadDelegate: self, delegateQueue: OperationQueue.main)
    }
    
    /// Restores the Application state by getting all the AVAssetDownloadTasks and restoring their Asset structs.
    func restorePersistenceManager() {
        guard !didRestorePersistenceManager else { return }
        
        didRestorePersistenceManager = true
        
        // Grab all the tasks associated with the assetDownloadURLSession
        assetDownloadURLSession.getAllTasks { tasksArray in
            // For each task, restore the state in the app by recreating Asset structs and reusing existing AVURLAsset objects.
            for task in tasksArray {
                guard let assetDownloadTask = task as? AVAssetDownloadTask, let assetName = task.taskDescription else { break }
                
                let urlAsset = assetDownloadTask.urlAsset
                let asset = Asset(name: assetName, urlAsset: urlAsset)
                
                self.activeDownloadsMap[assetDownloadTask] = asset
            }
            
            NotificationCenter.default.post(name: .AssetPersistenceManagerDidRestoreState, object: nil)
        }
    }

    /// Triggers the initial AVAssetDownloadTask for a given Asset.
    /// - Tag: DownloadStream
    public func downloadStream(for asset: Asset) {
 
        guard let task =
                assetDownloadURLSession.makeAssetDownloadTask(asset: asset.urlAsset,
                                                          assetTitle: "test title",
                                                          assetArtworkData: nil,
                                                              options: nil) else { return }

        // To better track the AVAssetDownloadTask, set the taskDescription to something unique for the sample.
        task.taskDescription = asset.name

        activeDownloadsMap[task] = asset

        task.resume()

        var userInfo = [String: Any]()
        userInfo[Asset.Keys.name] = asset.name
        userInfo[Asset.Keys.downloadState] = Asset.DownloadState.downloading.rawValue
        userInfo[Asset.Keys.downloadSelectionDisplayName] = ""
//        userInfo[Asset.Keys.downloadSelectionDisplayName] = displayNamesForSelectedMediaOptions(preferredMediaSelection)

        NotificationCenter.default.post(name: .AssetDownloadStateChanged, object: nil, userInfo: userInfo)
    }

    /// Returns an Asset given a specific name if that Asset is associated with an active download.
    func assetForStream(withName name: String) -> Asset? {
        var asset: Asset?

        for (_, assetValue) in activeDownloadsMap where name == assetValue.name {
            asset = assetValue
            break
        }

        return asset
    }
    
    /// Returns an Asset pointing to a file on disk if it exists.
    public func localAssetForStream(withName name: String) -> AVURLAsset? {
        let userDefaults = UserDefaults.standard
        print(userDefaults.dictionaryRepresentation())
        guard let localFileLocation = userDefaults.value(forKey: name) as? Data else { return nil }
        
        var bookmarkDataIsStale = false
        do {
            let url = try URL(resolvingBookmarkData: localFileLocation,
                                    bookmarkDataIsStale: &bookmarkDataIsStale)

            if bookmarkDataIsStale {
                fatalError("Bookmark data is stale!")
            }
            
            let urlAsset = AVURLAsset(url: url)
            return urlAsset
        } catch {
            fatalError("Failed to create URL from bookmark with error: \(error)")
        }
    }
    
    

    /// Returns the current download state for a given Asset.
    func downloadState(for asset: Asset) -> Asset.DownloadState {
        // Check if there is a file URL stored for this asset.
        if let localFileLocation = localAssetForStream(withName: asset.name)?.url {
            // Check if the file exists on disk
            if FileManager.default.fileExists(atPath: localFileLocation.path) {
                return .downloaded
            }
        }

        // Check if there are any active downloads in flight.
        for (_, assetValue) in activeDownloadsMap where asset.name == assetValue.name {
            return .downloading
        }

        return .notDownloaded
    }

    /// Deletes an Asset on disk if possible.
    /// - Tag: RemoveDownload
    func deleteAsset(_ asset: Asset) {
        let userDefaults = UserDefaults.standard

        do {
            if let localFileLocation = localAssetForStream(withName: asset.name)?.url {
                try FileManager.default.removeItem(at: localFileLocation)

                userDefaults.removeObject(forKey: asset.name)

                var userInfo = [String: Any]()
                userInfo[Asset.Keys.name] = asset.name
                userInfo[Asset.Keys.downloadState] = Asset.DownloadState.notDownloaded.rawValue

                NotificationCenter.default.post(name: .AssetDownloadStateChanged, object: nil,
                                                userInfo: userInfo)
            }
        } catch {
            print("An error occured deleting the file: \(error)")
        }
    }

    /// Cancels an AVAssetDownloadTask given an Asset.
    /// - Tag: CancelDownload
    func cancelDownload(for asset: Asset) {
        var task: AVAssetDownloadTask?

        for (taskKey, assetVal) in activeDownloadsMap where asset == assetVal {
            task = taskKey
            break
        }

        task?.cancel()
    }
}



/**
 Extend `AssetPersistenceManager` to conform to the `AVAssetDownloadDelegate` protocol.
 */
extension AssetPersistenceManager: AVAssetDownloadDelegate {

    /// Tells the delegate that the task finished transferring data.
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let task = task as? AVAssetDownloadTask,
              let asset = activeDownloadsMap.removeValue(forKey: task) else { return }
        
        // Prepare the basic userInfo dictionary that will be posted as part of our notification.
        var userInfo = [String: Any]()
        userInfo[Asset.Keys.name] = asset.name

        if let error = error as NSError? {
            switch (error.domain, error.code) {
            case (NSURLErrorDomain, NSURLErrorCancelled):
                userInfo[Asset.Keys.downloadState] = Asset.DownloadState.notDownloaded.rawValue

            case (NSURLErrorDomain, NSURLErrorUnknown):
                fatalError("Downloading HLS streams is not supported in the simulator.")

            default:
                fatalError("An unexpected error occured \(error.domain)")
            }
        }
        
        NotificationCenter.default.post(name: .AssetDownloadStateChanged, object: nil, userInfo: userInfo)
    }


    /// Method called when a child AVAssetDownloadTask completes.
    public func urlSession(_ session: URLSession,
                           assetDownloadTask: AVAssetDownloadTask,
                      didFinishDownloadingTo location: URL) {
        
        let userDefaults = UserDefaults.standard
        
        var userInfo = [String: Any]()
        guard let asset = activeDownloadsMap[assetDownloadTask] else { return }
        userInfo[Asset.Keys.name] = asset.name
        
        do {
            let bookmark = try location.bookmarkData()
            userDefaults.set(bookmark, forKey: asset.name)
        } catch {
            print("Failed to create bookmarkData for download URL.")
        }

        userInfo[Asset.Keys.downloadState] = Asset.DownloadState.downloaded.rawValue
        userInfo[Asset.Keys.downloadSelectionDisplayName] = ""
    
        NotificationCenter.default.post(name: .AssetDownloadStateChanged, object: nil, userInfo: userInfo)
    }

    /// Method to adopt to subscribe to progress updates of an AVAggregateAssetDownloadTask.
    public func urlSession(_ session: URLSession,
                           assetDownloadTask: AVAssetDownloadTask,
                                     didLoad timeRange: CMTimeRange,
                       totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                     timeRangeExpectedToLoad: CMTimeRange) {

        // This delegate callback should be used to provide download progress for your AVAssetDownloadTask.
        guard let asset = activeDownloadsMap[assetDownloadTask] else { return }

        var percentComplete = 0.0
        for value in loadedTimeRanges {
            let loadedTimeRange: CMTimeRange = value.timeRangeValue
            percentComplete +=
                loadedTimeRange.duration.seconds / timeRangeExpectedToLoad.duration.seconds
        }

        var userInfo = [String: Any]()
        userInfo[Asset.Keys.name] = asset.name
        userInfo[Asset.Keys.percentDownloaded] = percentComplete

        NotificationCenter.default.post(name: .AssetDownloadProgress, object: nil, userInfo: userInfo)
    }
}

extension Notification.Name {
    /// Notification for when download progress has changed.
    static let AssetDownloadProgress = Notification.Name(rawValue: "AssetDownloadProgressNotification")
    
    /// Notification for when the download state of an Asset has changed.
    static let AssetDownloadStateChanged = Notification.Name(rawValue: "AssetDownloadStateChangedNotification")
    
    /// Notification for when AssetPersistenceManager has completely restored its state.
    static let AssetPersistenceManagerDidRestoreState = Notification.Name(rawValue: "AssetPersistenceManagerDidRestoreStateNotification")
}
