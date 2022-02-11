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
const url =
  'http://ec2-13-53-83-250.eu-north-1.compute.amazonaws.com/vods3/_definst_/mp3:amazons3/audio-books-staging-private/76/8d/768d79dcea8ae1e9fa0fa1e7e9b48df7_1.mp3/playlist.m3u8?wowzatokenendtime=1644512013&wowzatokenstarttime=1644508413&wowzatokenhash=yD1DokrFnYgu5lrzsYS_nD8pRr2do26fnpWcsP2KR_PgknLWWMbVnecfp5ty5eCv';

const App = () => {
  useEffect(() => {
    setupIfNecessary();
  }, []);
  useEffect(() => {
    async function func() {
      const downloads = await TrackPlayer.getCompletedDownloads();
      console.log('downloads', downloads);
    }

    func();
  }, []);

  const onDownload = () => {
    TrackPlayer.download({
      url,
      id: 'xxx',
    });
  };
  const state = usePlaybackState();

  const onPlayPress = async () => {
    await togglePlayback(state);
  };

  const add = async () => {
    TrackPlayer.add({
      url,
      id: 'xxx',
      title: 'downloaded',
      type: TrackType.HLS,
    });
  };

  return (
    <SafeAreaView style={styles.screenContainer}>
      <StatusBar barStyle={'light-content'} />
      <Pressable onPress={onDownload}>
        <Text style={styles.secondaryActionButton}>Next</Text>
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
