"use strict";

var path = require("path");
var AdmZip = require("adm-zip");

var utils = require("./utilitiesNotificare");

var constants = {
  notificareServices: "notificare-services"
};



module.exports = function(context) {
  var cordovaAbove8 = utils.isCordovaAbove(context, 8);
  var cordovaAbove7 = utils.isCordovaAbove(context, 7);
  var defer;
  if (cordovaAbove8) {
    defer = require("q").defer();
  } else {
    defer = context.requireCordovaModule("q").defer();
  }
  
  var platform = context.opts.plugin.platform;
  var platformConfig = utils.getPlatformConfigs(platform);
  if (!platformConfig) {
    utils.handleError("Invalid platform", defer);
  }

    var wwwPath = utils.getResourcesFolderPath(context, platform, platformConfig);
    var sourceFolderPath = utils.getSourceFolderPath(context, wwwPath);
    var googleServicesZipFile = utils.getZipFile(sourceFolderPath, constants.notificareServices);
    if (!googleServicesZipFile) {
      throw new Error("No configuration zip file found (notificare-services-zip). You can check how to configure this file at: https://success.outsystems.com/Documentation/11/Extensibility_and_Integration/Mobile_Plugins/Firebase_Plugins");
    }
  
    var zip = new AdmZip(googleServicesZipFile);

    var targetPath = path.join(wwwPath, constants.notificareServices);
    zip.extractAllTo(targetPath, true);

    var files = utils.getFilesFromPath(targetPath);
    if (!files) {
      utils.handleError("No directory found", defer);
    }

    var fileName = files.find(function (name) {
      return name.endsWith(platformConfig.firebaseFileExtension);
    });
    if (!fileName) {
      utils.handleError("No file found", defer);
    }

    var sourceFilePath = path.join(targetPath, fileName);
    var destFilePath = path.join(context.opts.plugin.dir, fileName);

    if(!utils.checkIfFolderExists(destFilePath)){
      utils.copyFromSourceToDestPath(defer, sourceFilePath, destFilePath);
    }

    if (cordovaAbove7) {
      var destPath = path.join(context.opts.projectRoot, "platforms", platform, "app");
      if (utils.checkIfFolderExists(destPath)) {
        var destFilePath = path.join(destPath, fileName);
        if(!utils.checkIfFolderExists(destFilePath)){
          utils.copyFromSourceToDestPath(defer, sourceFilePath, destFilePath);
        }
      }
    }
  

  
      
  return defer.promise;
}
