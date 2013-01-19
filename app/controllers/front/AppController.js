var async = require('async');
var darkside = require('darkside');

var Branch = require('../../model/Branch');
var BaseController = require('./@BaseController');


var app_state_texts = {
  0: 'Idle',
  1: 'Building',
  2: 'Unit testing',
  3: 'Integration testing',
  4: 'Ready for deploy',
  5: 'Deploying',
  6: 'Running'
};

var process_state_texts = {
  '-2': 'Unregistered',
  '-1': 'Unknown',
  0: 'Stopped',
  1: 'Running'
};


var AppController = function (io, apps) {
  darkside.base(BaseController, this);

  this.$io = io;
  this.$apps = apps;
};

darkside.inherits(AppController, BaseController);

AppController.prototype.$deps = [ '$io', 'apps' ];


AppController.prototype['index'] = function (params) {
  var self = this;

  this.$apps.getAppNames(function (err, names) {
    if (err) return self.terminate(500, err);

    self.view['apps'] = names;
    self.render();
  });
};


AppController.prototype['new'] = function () {
  var self = this;
  var form = this.createAppForm();

  form.on('ready', function () {
    self.view['app_form'] = form;
    self.render();
  });

  form.on('submit', function (err, values) {
    if (err) self.terminate(400, err);

    self.$apps.create(values['name'], function (app) {
      self.redirectTo('app', app.name);
    });
  });
};

AppController.prototype.createAppForm = function () {
  var form = this.createForm('app');
  form.scheme = {
    'name': form.REQUIRED
  };

  return form;
};


AppController.prototype['app'] = function (params) {
  var self = this;
  var app = this.$apps.get(params['app']);

  app.getBranchList(function (err, branches) {
    if (err) return self.terminate(500, err);

    self.view['app'] = app.name;
    self.view['branches'] = branches;
    self.view['app_state_texts'] = app_state_texts;

    self.render();
  });
};


AppController.prototype['branch'] = function (params) {
  var self = this;
  var app = this.$apps.get(params['app']);
  var branch = app.getBranch(params['branch']);
  var rev = params['rev'] || 'HEAD';

  async.parallel({
    branch: function (done) {
      branch.getInfo(done);
    },
    processes: function (done) {
      branch.getProcesses(done);
    },
    commits: function (done) {
      branch.getRevisions(rev, 10, done);
    }
  }, function (err, results) {
    if (err) return self.terminate(500, err);

    self.view['app'] = app.name;
    self.view['branch'] = branch.name;
    self.view['info'] = results.branch;
    self.view['rev'] = rev.replace(/^\./, '#');
    self.view['processes'] = results.processes;
    self.view['commits'] = results.commits;
    self.view['app_state_texts'] = app_state_texts;
    self.view['job_states'] = Branch.JobStates;
    self.view['process_state_texts'] = process_state_texts;

    self.render();
  });
};


AppController.prototype['process'] = function (params) {
  var self = this;
  var app = this.$apps.get(params['app']);
  var branch = app.getBranch(params['branch']);
  var process = branch.getProcess(params['process']);

  async.parallel({
    log: function (done) {
      process.getLog(done);
    }
  }, function (err, results) {
    if (err) return self.terminate(500, err);

    self.view['app'] = app.name;
    self.view['branch'] = branch.name;
    self.view['process'] = process.name;
    self.view['log'] = results.log;
    self.render();

    var io_ns = '/apps/' + app.name + '/' + branch.name + '/' + process.name;
    var io = self.$io.of(io_ns);
    var tail = process.startTailingLog();
    if (tail) {
      tail.on('data', function (chunk) {
        io.emit('log', chunk.toString());
      });
    }
  });
};


AppController.prototype['revisions'] = function (params) {
  var self = this;
  var app = this.$apps.get(params['app']);
  var branch = app.getBranch(params['branch']);

  branch.getRevisions('HEAD', 20, function (err, revisions) {
    if (err) return self.terminate(500, err);

    self.view['app'] = app.name;
    self.view['branch'] = branch.name;
    self.view['revisions'] = revisions;
    self.render();
  });
};


module.exports = AppController;
