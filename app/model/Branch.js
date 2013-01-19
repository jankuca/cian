var async = require('async');
var exec = require('child_process').exec;
var fs = require('fs');
var path = require('path');

var Process = require('./Process');


var Branch = function (app, name, path) {
  this.name = name;
  this.path = path;

  this.app_ = app;
  this.processes_ = {};
  this.tailing_log_ = false;
};


Branch.JobStates = {
  UNREGISTERED: -2,
  UNKNOWN: -1,
  STOPPED: 0,
  RUNNING: 1
};

Branch.JobStateTexts = {
  'stop/waiting': Branch.JobStates.STOPPED,
  'start/running': Branch.JobStates.RUNNING
};


Branch.prototype.getInfo = function (callback) {
  var self = this;

  this.app_.getBranches(function (err, branches) {
    if (err) {
      return callback(err, null);
    }

    var branch = branches[self.name];
    if (!branch) {
      return callback(new Error('No such branch'), null);
    }

    branch.name = self.name;
    callback(null, branch);
  });
};


Branch.prototype.getProcesses = function (callback) {
  var self = this;

  async.parallel({
    jobs: function (done) {
      self.getJobList_(done)
    },
    processes: function (done) {
      self.getProcessList_(done);
    }
  }, function (err, results) {
    if (err) {
      return callback(err, null);
    }

    var processes = [];
    results.processes.forEach(function (process) {
      for (var i = 1, job; job = results.jobs[process.name + '.' + i]; ++i) {
        processes.push({
          name: process.name + '.' + i,
          cmd: process.cmd,
          pid: job.pid,
          state: job.state
        });
      }
      if (i === 1) { // no jobs for the process
        processes.push({
          name: process.name,
          cmd: process.cmd,
          pid: null,
          state: Branch.JobStates.UNREGISTERED
        });
      }
    });

    processes.sort(function (a, b) {
      if (a.name === b.name) return 0;
      return (a.name < b.name) ? -1 : 1;
    });

    callback(null, processes);
  });
};


Branch.prototype.getProcess = function (process_name) {
  if (!this.processes_[process_name]) {
    this.processes_[process_name] = new Process(this, process_name);
  }

  return this.processes_[process_name];
};


Branch.prototype.getRevisions = function (start, count, callback) {
  var cmd = 'git log ' + start + ' -n ' + count + '  --format="%ci|%h|%d|%s"';
  exec(cmd, function (err, stdout, stderr) {
    if (err) {
      return callback(new Error(stderr.toString()), null);
    }

    var lines = stdout.toString().split('\n').slice(0, -1);
    var revisions = lines.map(function (line) {
      var cols = line.split('|');
      var tags = cols[2] ? cols[2].replace(/(^\s\(|\)$)/g, '').split(', ') : [];
      return {
        id: tags.length ? tags[0] : cols[1],
        created_at: new Date(cols[0]),
        sha1: cols[1],
        tags: tags,
        message: cols.slice(3).join('|')
      };
    });
    callback(null, revisions);
  });
};


Branch.prototype.getJobList_ = function (callback) {
  return callback(null, {
    'web.1': {
      state: Branch.JobStates.RUNNING,
      pid: 1235
    }
  });

  var job_name = this.app_.name + '_' + this.name;
  exec('initctl list | grep ' + job_name, function (err, stdout, stderr) {
    if (err) {
      return callback(new Error('Failed to list jobs: ' + stderr), null);
    }

    var lines = stdout.toString().split(/\n/).slice(0, -1);
    var jobs = {};
    lines.forEach(function (line) {
      var job = line.split(/,\s/);
      var name = job[0].split(/\s/);
      var key = name[0].split('-').slice(1).join('.');
      jobs[key] = {
        state: Branch.JobStates[name[1]] || Branch.JobStates.UNKNOWN,
        pid: job[1] ? job[1].match(/\d+/)[0] : null
      };
    });
    callback(null, jobs);
  });
};


Branch.prototype.getProcessList_ = function (callback) {
  var procfile_path = path.join(this.path, 'Procfile');
  fs.readFile(procfile_path, 'utf8', function (err, data) {
    if (err) {
      if (err.code !== 'ENOENT') {
        return callback(err, null);
      } else {
        return callback(null, []);
      }
    }

    var lines = data.split(/\s*\n\s*/).slice(0, -1);
    var processes = lines.map(function (line) {
      var name = line.match(/^([^:]+)\s*:\s*/);
      return {
        name: name[1],
        cmd: line.substr(name[0].length)
      }
    });

    callback(null, processes);
  });
};


module.exports = Branch;
