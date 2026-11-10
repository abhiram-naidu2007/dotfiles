(() => {
  const isAv1 = (t) => typeof t === "string" && /av01/i.test(t);
  const isType = MediaSource.isTypeSupported.bind(MediaSource);
  MediaSource.isTypeSupported = (t) => !isAv1(t) && isType(t);
  const canPlay = HTMLMediaElement.prototype.canPlayType;
  HTMLMediaElement.prototype.canPlayType = function (t) { return isAv1(t) ? "" : canPlay.call(this, t); };
  const mc = navigator.mediaCapabilities;
  if (mc && mc.decodingInfo) {
    const info = mc.decodingInfo.bind(mc);
    mc.decodingInfo = (c) => isAv1(c && c.video && c.video.contentType)
      ? Promise.resolve({ supported: false, smooth: false, powerEfficient: false })
      : info(c);
  }
})();
