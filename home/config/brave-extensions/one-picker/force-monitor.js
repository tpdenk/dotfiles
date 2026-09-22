(() => {
    const devices = navigator.mediaDevices;
    if (!devices?.getDisplayMedia)
        return;

    const original = devices.getDisplayMedia.bind(devices);

    devices.getDisplayMedia = function getDisplayMedia(constraints) {
        const options = {...constraints};
        const video = typeof options.video === "object" && options.video !== null ? {...options.video} : {};

        video.displaySurface = "monitor";
        options.video = video;

        delete options.preferCurrentTab;
        delete options.selfBrowserSurface;
        delete options.surfaceSwitching;

        return original(options);
    };
})();
