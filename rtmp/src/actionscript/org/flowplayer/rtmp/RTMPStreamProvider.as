/*
 * This file is part of Flowplayer, http://flowplayer.org
 *
 * By: Anssi Piirainen, <support@flowplayer.org>
 * Copyright (c) 2008 Flowplayer Ltd
 *
 * Released under the MIT License:
 * http://www.opensource.org/licenses/mit-license.php
 */

package org.flowplayer.rtmp {
	import flash.events.NetStatusEvent;
	import flash.net.NetStream;

	import org.flowplayer.controller.ConnectionProvider;
	import org.flowplayer.controller.NetStreamControllingStreamProvider;
	import org.flowplayer.model.Clip;
	import org.flowplayer.model.ClipEvent;
	import org.flowplayer.model.ClipEventType;
	import org.flowplayer.model.Plugin;
	import org.flowplayer.model.PluginModel;
	import org.flowplayer.util.PropertyBinder;
	import org.flowplayer.util.URLUtil;
	import org.flowplayer.util.VersionUtil;
	import org.flowplayer.view.Flowplayer;

	/**
	 * A RTMP stream provider. Supports following:
	 * <ul>
	 * <li>Starting in the middle of the clip's timeline using the clip.start property.</li>
	 * <li>Stopping before the clip file ends using the clip.duration property.</li>
	 * <li>Ability to combine a group of clips into one gapless stream.</li>
	 * </ul>
	 * <p>
	 * Stream group is configured in a clip like this:
	 * <code>
	 * { streams: [ { url: 'metacafe', duration: 20 }, { url: 'honda_accord', start: 10, duration: 20 } ] }
	 * </code>
	 * The group is played back seamlessly as one gapless stream. The individual streams in a group can
	 * be cut out from a larger file using the 'start' and 'duration' properties as shown in the example above.
	 * 
	 * @author api
	 */
	public class RTMPStreamProvider extends NetStreamControllingStreamProvider implements Plugin {

		private var _config : Config;
		private var _model : PluginModel;
		private var _bufferStart : Number = 0;
		private var _player : Flowplayer;
		private var _rtmpConnectionProvider : ConnectionProvider;
		private var _subscribingConnectionProvider : ConnectionProvider;
		private var _durQueryingConnectionProvider : ConnectionProvider;
		private var _previousClip : Clip;
		private var _dvrLiveStarted : Boolean;

		private var _receivedStop : Boolean;

		override protected function onNetStatus(event : NetStatusEvent) : void {
			log.info("onNetStatus(), code: " + event.info.code + ", paused? " + paused + ", seeking? " + seeking);

			if (event.info.code == "NetStream.Play.Start" && paused) {
				dispatchEvent(new ClipEvent(ClipEventType.SEEK, seekTarget));
				seeking = false;
			}
            
			if (event.info.code == "NetStream.Play.Start" && _config.dvrSubscribeLive && !_dvrLiveStarted) {
				netStream.seek(1000000); 
				_dvrLiveStarted = true;
			}
            
            
			if ( event.info.code == "NetStream.Play.Stop" ) {
				_receivedStop = true;
			}
			
			// #107, dispatch finish when we already got a stop
			// #113, dispatch finish also when we're around the end of the clip
            // && clip. duration > 0 added for this http://flowplayer.org/forum/8/46963
            if ( event.info.code == "NetStream.Buffer.Empty" && (_receivedStop || ((clip.duration - _player.status.time < 1) && clip.duration > 0))) {
                clip.dispatchBeforeEvent(new ClipEvent(ClipEventType.FINISH));
            }
        }
        
        override protected function onConnectionStatus(event:NetStatusEvent):void {
        	if (event.info.code == "NetConnection.Connect.IdleTimeOut") {
        		clip.dispatchEvent(new ClipEvent(ClipEventType.IDLE_TIMEOUT));
        	}
	    }
        
		/**
		 * Called by the player to set my model object.
		 */
		override public function onConfig(model : PluginModel) : void {
			log.debug("onConfig()");
			if (_model) return;
			_model = model;
			_config = new PropertyBinder(new Config(), null).copyProperties(model.config) as Config;
		}

		/**
		 * Called by the player to set the Flowplayer API.
		 */
		override public function onLoad(player : Flowplayer) : void {
			_player = player;
			if (_config.streamCallbacks) {
				log.debug("configuration has " + _config.streamCallbacks + " stream callbacks");
			} else {
				log.debug("no stream callbacks in config");
			}
			_model.dispatchOnLoad();
//			_model.dispatchError(PluginError.INIT_FAILED, "failed for no fucking reason");
		}

		public function get durationFunc() : String {
			return clip.getCustomProperty("rtmpDurationFunc") as String || _config.durationFunc;
		}

		override protected function getConnectionProvider(clip : Clip) : ConnectionProvider {

			if (clip.getCustomProperty("rtmpSubscribe") || _config.subscribe) {
				log.debug("using FCSubscribe to connect");
				if (!_subscribingConnectionProvider) {
					_subscribingConnectionProvider = new SubscribingRTMPConnectionProvider(_config);
				}
				return _subscribingConnectionProvider;
			}
			if (durationFunc) {
				log.debug("using " + durationFunc + " to fetch stream duration from the server");
				if (!_durQueryingConnectionProvider) {
					_durQueryingConnectionProvider = new DurationQueryingRTMPConnectionProvider(_config, durationFunc);
				}
				return _durQueryingConnectionProvider;
			}
			log.debug("using the default connection provider");
			if (!_rtmpConnectionProvider) {
				_rtmpConnectionProvider = new RTMPConnectionProvider(_config);
			}
			return _rtmpConnectionProvider;
		}

		/**
		 * Overridden to allow random seeking in the timeline.
		 */
		override public function get allowRandomSeek() : Boolean {
			return true;
		}

		
		/**
		 * Starts loading using the specified netStream and clip.
		 */
		override protected function doLoad(event : ClipEvent, netStream : NetStream, clip : Clip) : void {
			_bufferStart = 0;
			if (hasStreamGroup(clip)) {
				startStreamGroup(clip, netStream);
			} else {
				startStream(clip);
			}
		}

		private function startStream(clip : Clip) : void {
			_receivedStop = false;
			var streamName : String = getStreamName(clip);
            
			var start : int = clip.start > 0 ? clip.start : 0;
			var duration : int = clip.duration > 0 ? clip.duration + 1 /* let some time to the duration tracker */: -1;
			
			log.info("startStream() starting playback of stream '" + streamName + "', start: " + start + ", duration: " + duration);
			
			if ( clip.live ) {
				netStream.play(streamName, -1);
			} else if (_config.dvrSubscribeStart || _config.dvrSubscribeLive) {
				netStream.play(streamName, 0, -1);
			} else {
				netStream.play(streamName, start, duration);
			}
		}

		private function getStreamName(clip : Clip) : String {
			var url : String = clip.url;
			
			if (url.indexOf('http://') == -1 && URLUtil.isCompleteURLWithProtocol(url)) {
				var lastSlashPos : Number = url.lastIndexOf("/");
				return url.substring(lastSlashPos + 1);
			}
			
			return url;
		}

		/**
		 * Overridden to be able to store the latest seek target position.
		 */
		override protected function doSeek(event : ClipEvent, netStream : NetStream, seconds : Number) : void {
			_receivedStop = false;
			var time : Number = Math.floor(seconds);
			_bufferStart = time;
			
			super.doSeek(event, netStream, time);
		}

		override protected function doSwitchStream(event : ClipEvent, netStream : NetStream, clip : Clip, netStreamPlayOptions : Object = null) : void {
			_receivedStop = false;
			log.debug("doSwitchStream() calling play2()")

			_previousClip = clip;
			clip.currentTime = Math.floor(_previousClip.currentTime + netStream.time);
			_bufferStart = clip.currentTime;
			
			if (netStream.hasOwnProperty("play2") && netStreamPlayOptions && VersionUtil.isFlash10()) {
				import flash.net.NetStreamPlayOptions;
				
				if (netStreamPlayOptions is NetStreamPlayOptions) {
					log.debug("doSwitchStream() calling play2()")
					netStream.play2(netStreamPlayOptions as NetStreamPlayOptions);
				}
			} else {
				
				log.debug("Switching stream with netstream time: " + clip.currentTime);
				netStream.play(clip.url, clip.currentTime);
			}
		}

		override public function get bufferStart() : Number {
			if (!clip) return 0;
			return _bufferStart;
		}

		override public function get bufferEnd() : Number {
			if (!netStream) return 0;
			if (!clip) return 0;
			return bufferStart + netStream.bufferLength;
		}

		/**
		 * Starts streaming a stream group.
		 */
		protected function startStreamGroup(clip : Clip, netStream : NetStream) : void {
			var streams : Array = clip.customProperties.streams as Array;
			_receivedStop = false;
			log.debug("starting a group of " + streams.length + " streams");
			var totalDuration : int = 0;
			for (var i : Number = 0;i < streams.length;i++) {
				var stream : Object = streams[i];
				var duration : int = getDuration(stream);
				var reset : Object = i == 0 ? 1 : 0; 
				netStream.play(stream.url, getStart(stream), duration, reset);
				if (duration > 0) {
					totalDuration += duration;
				}
				log.debug("added " + stream.url + " to playlist, total duration " + totalDuration);
			}
			if (totalDuration > 0) {
				clip.duration = totalDuration;
			}
		}

		/**
		 * Does the specified clip have a configured stream group?
		 */
		protected function hasStreamGroup(clip : Clip) : Boolean {
			return clip.customProperties && clip.customProperties.streams;
		}

		private function getDuration(stream : Object) : int {
			return stream.duration || -1;
		}

		private function getStart(stream : Object) : int {
			return stream.start || 0;
		}

		public function getDefaultConfig() : Object {
			return null;
		}

		override public function get type() : String {
			return "rtmp";	
		}

		override public function get time() : Number {
			if (!netStream) return 0;
			return getCurrentPlayheadTime(netStream) + clip.currentTime;
		}
	}
}
