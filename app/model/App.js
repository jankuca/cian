var path = require('path');
var YAML = require('pyyaml');

var Branch = require('./Branch');


var App = function (name, app_path) {
  this.name = name;
  this.path = app_path;

  this.branches_ = {};
};


App.States = {
  IDLE: 0,
  BUILDING: 1,
  UNIT_TESTING: 2,
  INTEGRATION_TESTING: 3,
  READY: 4,
  DEPLOYING: 5,
  RUNNING: 6
};


App.prototype.getBranchList = function (callback) {
  this.getBranches(function (err, data) {
    if (err) {
      return callback(err, null)
    }

    var branches = Object.keys(data).map(function (name) {
      data[name].name = name;
      return data[name];
    });
    branches.sort(function (a, b) {
      if (a['last_updated_at'] === b['last_updated_at']) {
        return 0;
      }
      return (a['last_updated_at'] > b['last_updated_at']) ? -1 : 1;
    });
    callback(null, branches);
  });
};


App.prototype.getBranch = function (name, callback) {
  if (!this.branches_[name]) {
    var branch_path = path.join(this.path, name);
    this.branches_[name] = new Branch(this, name, branch_path);
  }

  return this.branches_[name];
};


App.prototype.getBranches = function (callback) {
  var branch_file_path = path.join(this.path, '.cian-branches.yml');
  YAML.load(branch_file_path, callback);
}


module.exports = App;
