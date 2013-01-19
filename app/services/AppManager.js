var fs = require('fs');
var path = require('path');

var App = require('../model/App');


var AppManager = function (options) {
  this.app_dir_ = options['dir'];

  this.apps_ = {};
};


AppManager.prototype.getAppNames = function (callback, ctx) {
  fs.readdir(this.app_dir_, function (err, filenames) {
    if (err) {
      callback.call(ctx, err, null);
    } else {
      var names = filenames.filter(function (name) {
        return name[0] !== '.';
      });
      callback.call(ctx, null, names);
    }
  });
};


AppManager.prototype.get = function (name) {
  if (!this.apps_[name]) {
    var app_path = path.join(this.app_dir_, name);
    this.apps_[name] = new App(name, app_path);
  }

  return this.apps_[name];
};


module.exports = AppManager;
