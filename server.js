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
  var filelist =  remuxFindInDir(sentrycampath, /\.mp4$/)
  res.json({filelist: filelist})
})

function remuxFindInDir (dir, filter, fileList = []) {
  const files = fs.readdirSync(dir);

  files.forEach((file) => {

    const filePath = path.join(dir, file);
    const fileStat = fs.lstatSync(filePath);

    if (fileStat.isDirectory()) {
       if (! fs.existsSync(filePath.replace(new RegExp("^" + sentrycampath ), tcampath ))) {
	 console.log('mkdir' + filePath.replace(new RegExp("^" + sentrycampath ), tcampath ))
         fs.mkdirSync(filePath.replace(new RegExp("^" + sentrycampath), tcampath), { recursive: true })
       }
      remuxFindInDir(filePath, filter, fileList);
    } else if (filter.test(filePath)) {
	console.log('remux' +  filePath.replace(new RegExp("^" + sentrycampath ), tcampath ))
	if (! fs.existsSync(filePath.replace(new RegExp("^" + sentrycampath ), tcampath ))) {
        exec('ffmpeg -err_detect ignore_err -i ' + filePath + ' -c copy ' + filePath.replace(new RegExp("^" + sentrycampath ), tcampath ),
            (error, stdout, stderr) => {
        console.log(stdout);
        console.log(stderr);
         if (error !== null) {
           console.log(`exec error: ${error}`);
         }
      }).on('exit', code => {
        console.log(code)
      });

        fileList.push({'commands':  filePath + " -c copy " + filePath.replace(new RegExp("^" + sentrycampath ), tcampath )} );
    }}
  });

  return fileList;
}


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

app.use('/video', function(req, res) {
  if (req.url.endsWith('.mp4')){
	  const path = tcampath + req.url
	  const stat = fs.statSync(path)
	  const fileSize = stat.size
	  const range = req.headers.range

	  if (range) {
	    const parts = range.replace(/bytes=/, "").split("-")
	    const start = parseInt(parts[0], 10)
	    const end = parts[1]
	      ? parseInt(parts[1], 10)
	      : fileSize-1

	    if(start >= fileSize) {
	      res.status(416).send('Requested range not satisfiable\n'+start+' >= '+fileSize);
	      return
	    }
	    const chunksize = (end-start)+1
	    const file = fs.createReadStream(path, {start, end})
	    const head = {
	      'Content-Range': `bytes ${start}-${end}/${fileSize}`,
	      'Accept-Ranges': 'bytes',
	      'Content-Length': chunksize,
	      'Content-Type': 'video/mp4',
	    }

	    res.writeHead(206, head)
	    file.pipe(res)
	  } else {
	    const head = {
	      'Content-Length': fileSize,
	      'Content-Type': 'video/mp4',
	    }
	    res.writeHead(200, head)
	    fs.createReadStream(path).pipe(res)
	  }
  } else {
    express.static( tcampath ), serveIndex( tcampath, { 'icons': true } ) 
  }
})

app.use(express.static(path.join(__dirname, 'build')));
app.get('/', function(req, res) {
  res.sendFile(path.join(__dirname, 'build', 'index.html'));
});

app.listen(8084, function () {
  console.log('Listening on port 8084!')
})
