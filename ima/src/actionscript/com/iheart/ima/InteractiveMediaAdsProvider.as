/*
 *	Copyright (c) 2011 Andrew Stone
 *	This file is part of flowplayer-ima.
 *
 *	flowplayer-streamtheworld is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 3 of the License, or
 *	(at your option) any later version.
 *
 *	flowplayer-streamtheworld is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with flowplayer-streamtheworld.  If not, see <http://www.gnu.org/licenses/>.
 */
package com.iheart.ima {
	import flash.net.NetStream;
	
	import org.flowplayer.controller.NetStreamControllingStreamProvider;
	import org.flowplayer.controller.StreamProvider;
	import org.flowplayer.controller.TimeProvider;
	import org.flowplayer.controller.VolumeController;
	import org.flowplayer.model.DisplayProperties;
	import org.flowplayer.model.Plugin;
	import org.flowplayer.model.PluginModel;
	import org.flowplayer.model.PluginEventType;
	import org.flowplayer.util.Log;
	import org.flowplayer.util.PropertyBinder;
	import org.flowplayer.view.Flowplayer;
	
	/**
	 * The mass of imports needed for IMA Ads from Google
	 */
	import com.google.ads.instream.api.Ad;
	import com.google.ads.instream.api.AdError;
	import com.google.ads.instream.api.AdErrorEvent;
	import com.google.ads.instream.api.AdEvent;
	import com.google.ads.instream.api.AdLoadedEvent;
	import com.google.ads.instream.api.AdSizeChangedEvent;
	import com.google.ads.instream.api.AdTypes;
	import com.google.ads.instream.api.AdsLoadedEvent;
	import com.google.ads.instream.api.AdsLoader;
	import com.google.ads.instream.api.AdsManager;
	import com.google.ads.instream.api.AdsManagerTypes;
	import com.google.ads.instream.api.AdsRequest;
	import com.google.ads.instream.api.AdsRequestType;
	import com.google.ads.instream.api.CompanionAd;
	import com.google.ads.instream.api.CompanionAdEnvironments;
	import com.google.ads.instream.api.CustomContentAd;
	import com.google.ads.instream.api.FlashAd;
	import com.google.ads.instream.api.FlashAdCustomEvent;
	import com.google.ads.instream.api.FlashAdsManager;
	import com.google.ads.instream.api.HtmlCompanionAd;
	import com.google.ads.instream.api.VastVideoAd;
	import com.google.ads.instream.api.VastWrapper;
	import com.google.ads.instream.api.VideoAd;
	import com.google.ads.instream.api.VideoAdsManager;

	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.external.ExternalInterface;
	import flash.geom.Point;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;

	import flash.utils.Dictionary;

	import org.flowplayer.model.Clip;
	import org.flowplayer.model.ClipEvent;
	import org.flowplayer.model.Playlist;

	import flash.display.DisplayObject;

	public class InteractiveMediaAdsProvider extends Sprite implements Plugin {
		private var log:Log = new Log(this);
		private var _config:Config;
		private var _model:PluginModel;
		private var _screen:DisplayProperties;
		private var _adsLoader:AdsLoader;
		private var _video:Video;
		
		private var _area:InteractiveMediaAds;
		
		public static const BEFORE_AD_LOAD:String = "onBeforeAdLoad";
		public static const AD_PLAY:String = "onAdPlay";
		
		public static const AD_ERROR:String = "onAdError";
		
		function InteractiveMediaAdsProvider(area:InteractiveMediaAds) {
			_area = area;
		}
		
		/**
		 * Plugin Methods
		 * -----------------------------------------------------------------------------------------
		 */
		
		public function getDefaultConfig():Object {
			return {
				top: 0,
				left: 0,
				width: '100%',
				height: '100%'
			};
		}
		
		public function onConfig(model:PluginModel):void {
			_model = model;
			_config = new PropertyBinder(new Config()).copyProperties(model.config) as Config;
		}
		
		public function onLoad(player:Flowplayer):void {
			_screen = player.pluginRegistry.getPlugin("screen") as DisplayProperties;
			_model.dispatchOnLoad();
		}
		
		/**
		 * Javascript Methods
		 * -----------------------------------------------------------------------------------------
		 */
		
		[External]
		public function playAd(url:String):void {
			if (!_model.dispatchBeforeEvent(PluginEventType.PLUGIN_EVENT, BEFORE_AD_LOAD)) {
				log.info('not playing ad');
				return;
			}
			
			log.info('before _adsLoader');
			if (!_adsLoader) {
				_adsLoader = new AdsLoader();
				_adsLoader.addEventListener(AdsLoadedEvent.ADS_LOADED, onAdsLoaded);
				_adsLoader.addEventListener(AdErrorEvent.AD_ERROR, onAdError);
			}
			
			log.info('before ad request');
			_adsLoader.requestAds(createAdsRequest(url));
			log.info('ad requested');
		}
		
		/**
		 * Private Methods
		 * -----------------------------------------------------------------------------------------
		 */
		
		private function createAdsRequest(url:String):AdsRequest {
			var request:AdsRequest = new AdsRequest(),
				width:int = _screen.getDisplayObject().width,
				height:int = _screen.getDisplayObject().height;
			
			request.adSlotWidth = width;
			request.adSlotHeight = height;
			
			_video = new Video(width, height);
			addChild(_video);
			
			this.width = width;
			this.height = height;
			
			log.info("WxH: " + this.width + "x" + this.height);
			
			request.disableCompanionAds = _config.disableCompanionAds;
			
			//request.adTagUrl = 'http://ad.doubleclick.net/pfadx/ccr.newyork.ny/whtz-fm;ccrcontent1=null;ccrcontent2=live;ccrcontent3=null;ccrlocalcontent=null;ccrpos=7005;sourceaffiliate=whtz-fm;ccrformat=CHRPOP;ccrmarket=NEWYORK-NY;sz=1000x27;u=ccrcontent1*null!ccrcontent2*live!ccrcontent3*null!ccrlocalcontent*null!ccrpos*7005!sourceaffiliate*whtz-fm!ccrformat*CHRPOP!ccrmarket*NEWYORK-NY!sz*1000x27!;ord=670389610108713.6';
			
			//request.adTagUrl = 'http://ad.doubleclick.net/pfadx/ccr.macon.ga.n/wibb-fm;ccrcontent1=null;ccrcontent2=live;ccrcontent3=null;ccrlocalcontent=null;ccrpos=7005;sourceaffiliate=null;ccrformat=URBAN;ccrmarket=MACON-GA;group=cc;sz=1000x27;u=ccrcontent1*null!ccrcontent2*live!ccrcontent3*null!ccrlocalcontent*null!ccrpos*7005!sourceaffiliate*null!ccrformat*URBAN!ccrmarket*MACON-GA!group*cc!sz*1000x27;ord=1326212688261';
			
			//request.adTagUrl = 'http://localhost/IHR/test/vast.xml';
			
			request.adTagUrl = url;
			
			request.adType = AdsRequestType.VIDEO;
			
			return request;
		}
		
		private function displayCompanions(adsManager:AdsManager):void {
			log.debug("AdsManager type: " + adsManager.type);
			
			var ads:Array = adsManager.ads;
			if (ads) {
				log.debug(ads.length + " ads loaded");
				for each (var ad:Ad in ads) {
					renderHtmlCompanionAd(
						ad.getCompanionAds(CompanionAdEnvironments.HTML, 300, 250),
						"300x250"
					);
				}
			}
		}
		
		private function renderHtmlCompanionAd(companionArray:Array, size:String):void {
			if (companionArray.length > 0) {
				log.debug("There are " + companionArray.length + " companions for this ad.");
				var companion:CompanionAd = companionArray[0] as CompanionAd;
				if (companion.environment == CompanionAdEnvironments.HTML) {
					log.debug("companion " + size + " environment: " + companion.environment);
					var htmlCompanion:HtmlCompanionAd = companion as HtmlCompanionAd;
					
					if (ExternalInterface.available) {
						log.debug('writing ad to external interface');
						ExternalInterface.call('writeIntoCompanionDiv', htmlCompanion.content, size);
					}
				}
			}
		}
		
		/**
		 * Ad Events
		 * -----------------------------------------------------------------------------------------
		 */
		 
		private function onAdsLoaded(e:AdsLoadedEvent):void {
			var adsManager:AdsManager = e.adsManager;
			
			adsManager.addEventListener(AdLoadedEvent.LOADED, onAdLoaded);
			adsManager.addEventListener(AdEvent.STARTED, onAdStarted);
			adsManager.addEventListener(AdErrorEvent.AD_ERROR, onAdError);
			
			if (adsManager.type == AdsManagerTypes.VIDEO) {
				log.info(adsManager.type);
				var videoAdsManager:VideoAdsManager = adsManager as VideoAdsManager;
				videoAdsManager.clickTrackingElement = _area;
				videoAdsManager.load(_video);
				videoAdsManager.play();
			}
			
			displayCompanions(adsManager);
		}
		
		private function onAdError(e:AdErrorEvent):void {
			var adError:AdError = e.error;
			log.error("Ad error: " + adError.errorMessage);
			log.error("Ad error code: " + adError.errorCode);
			if (adError.innerError != null) {
				log.error("Caused by: " + adError.innerError.message);
			}
			
			_model.dispatch(PluginEventType.PLUGIN_EVENT, AD_ERROR, adError.errorMessage);
		}
		
		private function onAdLoaded(event:AdLoadedEvent):void {
			log.info("Ad loaded: " + _video.videoHeight + "x" + _video.videoWidth);
		}
		
		private function onAdStarted(event:AdEvent):void {
			log.info("Ad started---: " + _video.videoHeight + "x" + _video.videoWidth);
			if (_video.videoWidth && _video.videoHeight) {
				_video.width = _video.videoWidth;
				_video.height = _video.videoHeight;
			}
		}
	}
}