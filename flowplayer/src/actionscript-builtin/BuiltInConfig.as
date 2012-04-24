package  {
    import com.iheart.ima.InteractiveMediaAdsProvider;
    import com.iheart.stw.StreamTheWorldProvider;
    import org.flowplayer.audio.AudioProvider;
    import org.flowplayer.rtmp.RTMPStreamProvider;

    public class BuiltInConfig {
        private var audio:AudioProvider;
        private var ima:InteractiveMediaAdsProvider;
        private var rtmp:RTMPStreamProvider;
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
                audio: {
                    "url": "org.flowplayer.audio.AudioProvider"
                },
                ima: {
                    "url": "com.iheart.ima.InteractiveMediaAdsProvider"
                },
                rtmp: {
                    "url": "org.flowplayer.rtmp.RTMPStreamProvider",
                    "netConnectionUrl": "rtmp://thumbplay123fs.fplive.net/thumbplay123/"
                },
                stw: {
                    "url": "com.iheart.stw.StreamTheWorldProvider"
                }
            }
        };
    }
}
