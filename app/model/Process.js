var exec = require('child_process').exec;
var path = require('path');


var Process = function (branch, name) {
  this.name = name;

  this.branch_ = branch;
  this.tailing_log_ = false;
}


Process.prototype.getLog = function (callback) {
  var log_path = this.getLogPath_();

  var log = '';
  var err = '';

  var p = exec('tail -100 "' + log_path + '"');
  p.stdout.on('data', function (chunk) {
    log += chunk;
  });
  p.stderr.on('data', function (chunk) {
    err += chunk;
  });
  p.on('exit', function (code) {
    if (code !== 0) {
      callback(new Error('Failed to load the log: ' + err), null);
    } else {
      callback(null, log);
    }
  });
};

Process.prototype.startTailingLog = function (callback) {
  if (this.tailing_log_) {
    return null;
  }

  var log_path = this.getLogPath_();

  var self = this;
  this.tailing_log_ = true;

  var p = exec('tail -f -0 "' + log_path + '"');
  p.on('exit', function () {
    self.tailing_log_ = false;
  })

  return p.stdout;
};


Process.prototype.getLogPath_ = function () {
  return path.join(this.branch_.path, this.name + '.log');
};


module.exports = Process;
