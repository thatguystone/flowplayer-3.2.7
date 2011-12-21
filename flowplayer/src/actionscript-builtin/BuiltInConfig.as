package  {
	import org.flowplayer.rtmp.RTMPStreamProvider;
	import org.flowplayer.audio.AudioProvider;
	import com.iheart.stw.StreamTheWorld;

	public class BuiltInConfig {
		private var rtmp:RTMPStreamProvider;
		private var audio:AudioProvider;
		private var stw:StreamTheWorld;
		
		public static const config:Object = { 
			"plugins": {
				controls: null,
				rtmp: {
					"url": "org.flowplayer.rtmp.RTMPStreamProvider",
					"netConnectionUrl": "rtmp://thumbplay123fs.fplive.net/thumbplay123/"
				},
				audio: {
					"url": "org.flowplayer.audio.AudioProvider"
				},
				stw: {
					"url": "com.iheart.stw.StreamTheWorld"
				}
			}
		};
	}
}
