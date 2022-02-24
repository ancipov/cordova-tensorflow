var exec = require('cordova/exec');

module.exports = {
    setModelWithCamera: function (options, successCallback, errorCallback) {
        cordova.exec(successCallback, errorCallback, "ApperyioML", "setModelWithCamera", [options]);
    }

};

