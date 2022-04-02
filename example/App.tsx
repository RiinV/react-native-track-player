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
    }

    func();
  }, []);

  const [url, setUrl] = useState('');

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
        setUrl(data.stream_url);
      });
  }, []);

  const onDownload = () => {
    console.log('react download');
    TrackPlayer.download({
      url,
      id: 'xxx',
      title: 'my title',
      artist: 'my artist',
    });
  };

  const state = usePlaybackState();

  const onPlayPress = async () => {
    await togglePlayback(state);
  };

  const add = async () => {
    console.log('add track');
    TrackPlayer.add({
      url,
      id: 'xxx',
      title: 'downloaded',
      artist: 'my artist',
      type: TrackType.HLS,
    });
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
