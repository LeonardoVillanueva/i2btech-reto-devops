const path = require('path');
const fs = require('fs');
const logfileFolder = path.join(__dirname, 'logs');
const logFilePath = path.join(logfileFolder, 'app.log');
const pino = require('pino');

if (!fs.existsSync(logfileFolder)) {
  fs.mkdirSync(logfileFolder);
}
const logger = pino(pino.destination(logFilePath));

var express = require('express');
var app = express();
var root = {
    msg: "ApiRest prueba",
};
var public = {
    public_token: "12837asd98a7sasd97a9sd7",
};
var private = {
    private_token: "TWFudGVuIGxhIENsYW1hIHZhcyBtdXkgYmllbgo=",
};

app.get('/', function (req, res) {
  res.send(root);
});

app.get('/public', function (req, res) {
  logger.info('Request received for /public');
  res.send(public);
});

app.get('/private', function (req, res) {
  logger.info('Request received for /private');
  res.send(private);
});

app.get('/health_check', function (req, res) {
  res.send("Ok");
});

app.listen(3000, '0.0.0.0', function () {
  console.log('Example app listening on port 3000!');
});
