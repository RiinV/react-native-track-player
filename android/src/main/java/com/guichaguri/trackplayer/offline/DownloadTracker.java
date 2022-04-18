package com.guichaguri.trackplayer.offline;
/*
 * Copyright (C) 2017 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import android.content.Context;
import android.content.DialogInterface;
import android.net.Uri;
import android.widget.Toast;

import androidx.annotation.Nullable;
import androidx.fragment.app.FragmentManager;

import com.google.android.exoplayer2.C;
import com.google.android.exoplayer2.RenderersFactory;
import com.google.android.exoplayer2.offline.Download;
import com.google.android.exoplayer2.offline.DownloadCursor;
import com.google.android.exoplayer2.offline.DownloadHelper;
import com.google.android.exoplayer2.offline.DownloadIndex;
import com.google.android.exoplayer2.offline.DownloadManager;
import com.google.android.exoplayer2.offline.DownloadRequest;
import com.google.android.exoplayer2.offline.DownloadService;
import com.google.android.exoplayer2.trackselection.DefaultTrackSelector;
import com.google.android.exoplayer2.trackselection.MappingTrackSelector.MappedTrackInfo;
import com.google.android.exoplayer2.upstream.DataSource;
import com.google.android.exoplayer2.util.Log;
import com.google.android.exoplayer2.util.Util;
import com.guichaguri.trackplayer.R;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArraySet;
import java.util.function.Predicate;
import java.util.stream.Collectors;

/**
 * Tracks media that has been downloaded.
 */
public class DownloadTracker {

    /**
     * Listens for changes in the tracked downloads.
     */
    public interface Listener {

        /**
         * Called when the tracked downloads changed.
         */
        void onDownloadsChanged(String trackId, String status);
    }

    private static final String TAG = "DownloadTracker";

    private final Context context;
    private final DataSource.Factory dataSourceFactory;
    private final CopyOnWriteArraySet<Listener> listeners;
    private final HashMap<String, Download> downloads;
    private final DownloadIndex downloadIndex;
    private final DefaultTrackSelector.Parameters trackSelectorParameters;

    public DownloadTracker(
            Context context, DataSource.Factory dataSourceFactory, DownloadManager downloadManager) {
        this.context = context.getApplicationContext();
        this.dataSourceFactory = dataSourceFactory;
        listeners = new CopyOnWriteArraySet<>();
        downloads = new HashMap<>();
        downloadIndex = downloadManager.getDownloadIndex();
        trackSelectorParameters = DownloadHelper.getDefaultTrackSelectorParameters(context);
        downloadManager.addListener(new DownloadManagerListener());
        loadDownloads();
    }

    public void addListener(Listener listener) {
        listeners.add(listener);
    }

    public void removeListener(Listener listener) {
        listeners.remove(listener);
    }

    public boolean isDownloaded(String id) {
        Download download = downloads.get(id);
        return download != null && download.state != Download.STATE_FAILED;
    }

    public DownloadRequest getDownloadRequest(String id) {
        Download download = downloads.get(id);
        return download != null && download.state != Download.STATE_FAILED ? download.request : null;
    }

    public void startDownload(
            String name,
            Uri uri,
            String id,
            RenderersFactory renderersFactory) {

        Download download = downloads.get(id);
        Log.d("Offline", "start download value of " + String.valueOf(download));
        if (download == null) {
            new StartDownloadDialogHelper(DownloadHelper.forHls(context, uri, dataSourceFactory, renderersFactory),
                    name, id);
        }
    }

    public void removeDownload(
            String trackId) {
        Download download = downloads.get(trackId);
        Log.d("Offline", "remove " + String.valueOf(download));
        if (download != null) {
            DownloadService.sendRemoveDownload(
                    context, DemoDownloadService.class, download.request.id, /* foreground= */ false);
        }
    }

    public void removeDownloadStartsWith(
            String prefix) {
        for (Map.Entry<String, Download> downloadEntry : downloads.entrySet()) {
            if (downloadEntry.getKey().startsWith(prefix)) {
                Download download = downloadEntry.getValue();
                Log.d("Offline", "remove " + String.valueOf(download));
                if (download != null) {
                    DownloadService.sendRemoveDownload(
                            context, DemoDownloadService.class, download.request.id, /* foreground= */ false);
                }
            }
        }
    }

    public List<String> getDownloads() {
        List<Download> downloadsList = new ArrayList(downloads.values());
        List<String> result = new ArrayList<>();

        for (Download download : downloadsList) {
            if (download != null && download.state == Download.STATE_COMPLETED) {
                result.add(download.request.id);
            }
        }

        return result;
    }

    public List<String> getActiveDownloads() {
        List<Download> downloadsList = new ArrayList(downloads.values());
        List<String> result = new ArrayList<>();

        List<Integer> states = Arrays.asList(Download.STATE_DOWNLOADING, Download.STATE_QUEUED,
                Download.STATE_RESTARTING);

        for (Download download : downloadsList) {
            if (download != null && states.contains(download.state)) {
                result.add(download.request.id);
            }
        }

        return result;
    }

    private void loadDownloads() {
        try (DownloadCursor loadedDownloads = downloadIndex.getDownloads()) {
            while (loadedDownloads.moveToNext()) {
                Download download = loadedDownloads.getDownload();
                downloads.put(download.request.id, download);
            }
        } catch (IOException e) {
            Log.w(TAG, "Failed to query downloads", e);
        }
    }

    private class DownloadManagerListener implements DownloadManager.Listener {

        @Override
        public void onDownloadChanged(DownloadManager downloadManager, Download download) {
            downloads.put(download.request.id, download);
            for (Listener listener : listeners) {
                String status = download.state == Download.STATE_COMPLETED ? "completed" : "unknown";
                listener.onDownloadsChanged(download.request.id, status);
            }
        }

        @Override
        public void onDownloadRemoved(DownloadManager downloadManager, Download download) {
            downloads.remove(download.request.id);
            for (Listener listener : listeners) {
                listener.onDownloadsChanged(download.request.id, "removed");
            }
        }
    }

    private final class StartDownloadDialogHelper implements DownloadHelper.Callback {
        private final DownloadHelper downloadHelper;
        private final String name;
        private final String id;

        public StartDownloadDialogHelper(DownloadHelper downloadHelper, String name, String id) {
            this.downloadHelper = downloadHelper;
            this.name = name;
            this.id = id;
            downloadHelper.prepare(this);
        }

        @Override
        public void onPrepared(DownloadHelper helper) {
            startDownload(id);
            downloadHelper.release();
        }

        @Override
        public void onPrepareError(DownloadHelper helper, IOException e) {
            Toast.makeText(context, R.string.download_start_error, Toast.LENGTH_LONG).show();
            Log.e(
                    TAG,
                    e instanceof DownloadHelper.LiveContentUnsupportedException
                            ? "Downloading live content unsupported"
                            : "Failed to start download",
                    e);
        }

        private void startDownload(String id) {
            startDownload(buildDownloadRequest(id));
        }

        private void startDownload(DownloadRequest downloadRequest) {
            Log.d("Offline", "start request");
            DownloadService.sendAddDownload(
                    context, DemoDownloadService.class, downloadRequest, /* foreground= */ false);
        }

        private DownloadRequest buildDownloadRequest(String id) {
            return downloadHelper.getDownloadRequest(id, Util.getUtf8Bytes(name));
        }
    }
}
