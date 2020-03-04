const express = require('express')
const fs = require('fs')
const path = require('path')
const app = express()
const serveIndex = require( "serve-index" )
const dirTree = require("directory-tree")
var cors = require("cors")
var tcampath = '/savetsla/savepoint/TeslaCam'
var sentrycampath = '/tslausb/TeslaCam'
const { exec } = require('child_process');


app.use(cors())

app.use("/root", express.static( '/' ), serveIndex( '/', { 'icons': true } ) )
app.use("/TeslaCam", express.static( tcampath ), serveIndex( tcampath, { 'icons': true } ))

app.get('/remount', function(req, res) {
   exec('sh remount.sh',
     (error, stdout, stderr) => {
        console.log(stdout);
        console.log(stderr);
         if (error !== null) {
           console.log(`exec error: ${error}`);
           res.send("error");
         }
      }).on('exit', code => {
	console.log(code)
	if (code === 0) {
	res.send('success');
        }
});
})

app.get('/remux', function(req, res) {
   exec('sh upmp4.sh',
     (error, stdout, stderr) => {
        console.log(stdout);
        console.log(stderr);
         if (error !== null) {
           console.log(`exec error: ${error}`);
           res.send("error");
         }
      }).on('exit', code => {
	console.log(code)
	if (code === 0) {
	res.send('success');
        }
});
})

app.get('/allfiles', function(req, res) {
  console.log( findInDir(tcampath, /\.mp4$/) )
  var filelist =  findInDir(tcampath, /\.mp4$/)
  res.json({filelist: filelist})
})

function findInDir (dir, filter, fileList = []) {
  const files = fs.readdirSync(dir);

  files.forEach((file) => {

    const filePath = path.join(dir, file);
    const fileStat = fs.lstatSync(filePath);

    if (fileStat.isDirectory()) {
      findInDir(filePath, filter, fileList);
    } else if (filter.test(filePath)) {
      fileList.push({'name': file, 'webkitRelativePath' : filePath.replace(new RegExp("^" + tcampath ), 'TeslaCam')});
    }
  });

  return fileList;
}

app.use(express.static(path.join(__dirname, 'build')));
app.get('/', function(req, res) {
  res.sendFile(path.join(__dirname, 'build', 'index.html'));
});

app.listen(8084, function () {
  console.log('Listening on port 8084!')
})
