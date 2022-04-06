import React, {useEffect, useState} from 'react';
import {
  Image,
  Pressable,
  SafeAreaView,
  StatusBar,
  StyleSheet,
  Text,
  TouchableWithoutFeedback,
  View,
} from 'react-native';
import Slider from '@react-native-community/slider';
import TrackPlayer, {
  Capability,
  Event,
  RepeatMode,
  State,
  TrackType,
  usePlaybackState,
  useProgress,
  useTrackPlayerEvents,
} from 'react-native-track-player';

const setupIfNecessary = async () => {
  // if app was relaunched and music was already playing, we don't setup again.
  const currentTrack = await TrackPlayer.getCurrentTrack();
  if (currentTrack !== null) {
    return;
  }

  await TrackPlayer.setupPlayer({});
  await TrackPlayer.updateOptions({
    stopWithApp: false,
    capabilities: [
      Capability.Play,
      Capability.Pause,
      Capability.SkipToNext,
      Capability.SkipToPrevious,
      Capability.Stop,
    ],
    compactCapabilities: [Capability.Play, Capability.Pause],
  });
};

const togglePlayback = async (playbackState: State) => {
  const currentTrack = await TrackPlayer.getCurrentTrack();
  if (currentTrack == null) {
    // TODO: Perhaps present an error or restart the playlist?
  } else {
    if (playbackState !== State.Playing) {
      await TrackPlayer.play();
    } else {
      await TrackPlayer.pause();
    }
  }
};

// 'https://playertest.longtailvideo.com/adaptive/alt-audio-no-video/sintel/playlist.m3u8'

const App = () => {
  useEffect(() => {
    setupIfNecessary();
  }, []);

  useEffect(() => {
    async function func() {
      console.log('hi downloads');
      const downloads = await TrackPlayer.getCompletedDownloads();
      console.log('downloads', downloads);
      const active = await TrackPlayer.getActiveDownloads();
      console.log('active', active);
    }

    func();
  }, []);

  const [url1, setUrl1] = useState('');
  const [url2, setUrl2] = useState('');

  useTrackPlayerEvents([Event.DownloadChanged], event => {
    console.log('event', event);
  });

  useEffect(() => {
    fetch(
      'https://audio.dev.rahvaraamat.ee/audio/product-chapter/view?id=342',
      {
        headers: {
          store: 'WEB3',
        },
      },
    )
      .then(response => {
        return response.json();
      })
      .then(data => {
        setUrl1(data.stream_url);
      });

    fetch(
      'https://audio.dev.rahvaraamat.ee/audio/product-chapter/view?id=345',
      {
        headers: {
          store: 'WEB3',
        },
      },
    )
      .then(response => {
        return response.json();
      })
      .then(data => {
        setUrl2(data.stream_url);
      });
  }, []);

  const onDownload = () => {
    console.log('react download');
    TrackPlayer.download([
      {
        url: url1,
        id: 'a1',
        title: 'my title 2',
        artist: 'my artist 2',
      },
      {
        url: url2,
        id: 'a2',
        title: 'my title 3',
        artist: 'my artist 3',
      },
    ]);
  };

  const state = usePlaybackState();

  const onPlayPress = async () => {
    await togglePlayback(state);
  };

  const add = async () => {
    console.log('add track');
    TrackPlayer.add({
      url: url1, // TODO: can't be empty for android
      id: 'f',
      title: 'downloaded',
      artist: 'my artist',
      type: TrackType.HLS,
    });
  };

  const onDelete = async () => {
    console.log('delete track');
    await TrackPlayer.removeDownload('d');
  };

  const onReset = async () => {
    TrackPlayer.reset();
  };

  const removeStarts = async () => {
    await TrackPlayer.removeDownloadStartsWith('a');
  };

  return (
    <SafeAreaView style={styles.screenContainer}>
      <StatusBar barStyle={'light-content'} />
      <Pressable onPress={onDownload}>
        <Text style={styles.secondaryActionButton}>Download</Text>
      </Pressable>
      <Pressable onPress={add}>
        <Text style={styles.secondaryActionButton}>Add</Text>
      </Pressable>
      <Pressable onPress={onPlayPress}>
        <Text style={styles.secondaryActionButton}>Play</Text>
      </Pressable>
      <Pressable onPress={onDelete}>
        <Text style={styles.secondaryActionButton}>delete</Text>
      </Pressable>
      <Pressable onPress={onReset}>
        <Text style={styles.secondaryActionButton}>reset</Text>
      </Pressable>
      <Pressable onPress={removeStarts}>
        <Text style={styles.secondaryActionButton}>remove starts</Text>
      </Pressable>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  screenContainer: {
    flex: 1,
    backgroundColor: '#212121',
    alignItems: 'center',
  },

  secondaryActionButton: {
    margin: 20,
    fontSize: 14,
    color: '#FFD479',
  },
});

export default App;
