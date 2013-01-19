var darkside = require('darkside');
var http = require('http');
var net = require('net');
var path = require('path');

var app = darkside.create(__dirname, { ws: true });
var tcp = net.createServer();
var port = Number(process.env['PORT']) || 9001;


app.router.setRouteDeclaration('./routes.declaration');
app.services.setServiceDeclaration('./services.declaration');


var handleTCPRequest = function (data, socket) {
  var lines = data.split('\n');
  var parts = lines[0].split(/\s/);

  var req = new http.IncomingMessage();
  req.method = parts[0];
  req.url = parts[1];
  req.headers['host'] = 'localhost';

  var res = { status: 0 };
  res.writeHead = function (status, headers) {
    res.status = Number(status);
    socket.write(res.status + '\n');
  };
  res.write = function () {};
  res.end = function (a) {
    if (!res.status) {
      res.writeHead(200);
    }
    socket.end();
    res.writeHead = null;
    res.write = null;
    res.end = null;
  };

  var request = new darkside.ServerRequest(req);
  var response = new darkside.HTTPServerResponse(res);
  app.server.handle(request, response);
};

tcp.on('connection', function (socket) {
  var data = '';
  socket.on('data', function (chunk) {
    data += chunk;
    if (data.indexOf('\n') !== -1) {
      handleTCPRequest(data, socket);
    }
  });
});


app.run(port);
tcp.listen(port + 1);
