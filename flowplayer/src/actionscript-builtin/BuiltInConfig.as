package  {
	import org.flowplayer.rtmp.RTMPStreamProvider;
	import org.flowplayer.audio.AudioProvider;
	import com.iheart.stw.StreamTheWorldProvider;

	public class BuiltInConfig {
		private var rtmp:RTMPStreamProvider;
		private var audio:AudioProvider;
		private var stw:StreamTheWorldProvider;
		
		public static const config:Object = {
			//don't show any errors on FP's screen
			showErrors: false,

			//hide the big play button that FP shows by default
			play: null,

			//make the player look a bit nicer on the page
			canvas: {
				backgroundColor: '#000000',
				backgroundGradient: 'none'
			},
			
			plugins: {
				controls: null,
				rtmp: {
					"url": "org.flowplayer.rtmp.RTMPStreamProvider",
					"netConnectionUrl": "rtmp://thumbplay123fs.fplive.net/thumbplay123/"
				},
				audio: {
					"url": "org.flowplayer.audio.AudioProvider"
				},
				stw: {
					"url": "com.iheart.stw.StreamTheWorldProvider"
				}
			}
		};
	}
}
