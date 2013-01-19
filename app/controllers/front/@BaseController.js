var darkside = require('darkside');


var BaseController = function () {
  darkside.base(darkside.ViewController, this);

  this.view['moment'] = require('moment');
};

darkside.inherits(BaseController, darkside.ViewController);


module.exports = BaseController;
