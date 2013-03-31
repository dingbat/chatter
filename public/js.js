padTimeouts = {};
boardTimeouts = {};
boards = {};
isDragging = false;

source = new EventSource('/stream');

source.addEventListener('error', function(e) {
console.log("error == "+e);
if (e.eventPhase == EventSource.CLOSED) {
  // Connection was closed.
  console.log("closed.");
}
}, false);

function chatCode(name)
{
var a = "<pre id='chat-"+name+"' class='chatbox'></pre> \
<form id='form-"+name+"'><input id='msg-"+name+"' placeholder='type message here...' /></form>";
return a;
}

function padCode(name)
{
var a = "<textarea id='pad-"+name+"' />";
return a;
}

function boardCode(name)
{
var a = "<canvas style='border: 1px solid black; background-color:white;' id='board-"+name+"' width='400' height='250'></canvas><button onclick='clearBoard(\""+name+"\")'>clr</button>";
return a;
}

function buildChatWindow(name)
{
var a = chatCode(name);
makeWindow('window-'+name, name+' room',a, false);
connectToRoom(name);
}

function buildPadWindow(name)
{
var a = padCode(name);
makeWindow('window-'+name, name+' pad',a, false);
connectToPad(name);
}

function buildBoardWindow(name)
{
var a = boardCode(name);
makeWindow('window-'+name, name+' board',a, true);
connectToBoard(name);
}

function newWindow(type, btn)
{
var name = $(btn).parent().find('#namefield').val();

var wind = $(btn).parent().parent().parent().parent();
wind.attr('id', 'window-'+type+'-'+name);

wind.find(".title").html(name+" "+type);

if (type == "room")
{
  var a = chatCode(name);
  wind.find(".content").html(a);
  
  connectToRoom(name);
}

if (type == "pad")
{
  var a = padCode(name);
  wind.find(".content").html(a);
  
  connectToPad(name);
}

if (type == "board")
{
  var a = boardCode(name);
  wind.find(".content").html(a);
  
  connectToBoard(name);
}
}

function killWindow(x)
{
var win = $(x).parent().parent().parent();
win.remove();
}

function makeWindow(id, title, content, board)
{
var a = "<div id='"+id+"' class='window' style='width:"+(board ? "430px" : "250px")+"'> \
  <div class='titlebar'><div class='title'>"+title+"</div><div class='kill'><a href='#' style='text-decoration:none' onclick='killWindow(this)'>x</a></div></div> \
  <div class='content'> \
  "+content+" \
  </div> \
</div> \
";

$('#windows').append(a);

if (!board)
{
  $('#'+id).draggable({ cursor: "move", stack: "#windows div", scroll:false, containment: "parent"});
  $('#'+id).resizable();
}
else
{
  $('#'+id).draggable({ cursor: "move", stack: "#windows div", scroll:false, containment: "parent", handle: "div.titlebar"});
}
}

function makeBox(type)
{
var a = "<div class='newtext'> \
<div class='newcontent'> \
    name your new "+type+":<br> \
    <input id='namefield' /> \
    <button id='temp-btn' onclick='newWindow(\""+type+"\", this)'>go!</button> \
</div> \
</div>";

makeWindow('temp-win', 'new '+type, a, type=="board");
$('#temp-win').attr('id', '');
}

function getPosition(e) {

  //this section is from http://www.quirksmode.org/js/events_properties.html
  var targ;
  if (!e)
      e = window.event;
  if (e.target)
      targ = e.target;
  else if (e.srcElement)
      targ = e.srcElement;
  if (targ.nodeType == 3) // defeat Safari bug
      targ = targ.parentNode;

  // jQuery normalizes the pageX and pageY
  // pageX,Y are the mouse positions relative to the document
  // offset() returns the position of the element relative to the document
  var x = e.pageX - $(targ).offset().left;
  var y = e.pageY - $(targ).offset().top;

  return {"x": x, "y": y};
}

function connectToRoom(name)
{
source.addEventListener('chat-'+name, function(e) 
{
  if ($('#chat-'+name).length == 0)
  {
    this.removeEventListener('chat-'+name,arguments.callee,false);
    return;
  }
  
  var dat = e.data.split("\n"); 
  var user = dat[0];
  var msg = dat[1];
  $('#chat-'+name).append("<b>" + user + "</b>: "+msg+"\n");

  console.log("being chatted at by "+user);

}, false);

$('#form-'+name).on('submit',function(e) {
  var msgBox = $('#msg-'+name);

  var user = $('#user').val();
  if (user.length == 0)
  {
    user = "anon";
  }
  $.post('/chat', {name: name, msg: msgBox.val(), user: user});
  msgBox.val('');
  msgBox.focus();
  e.preventDefault();
});

$.get('/chat?name='+name, function(data)
{
  $('#chat-'+name).html(data);
});
}

function connectToPad(name)
{
source.addEventListener('pad-'+name, function(e) 
{
  if ($('#pad-'+name).length == 0)
  {
    this.removeEventListener('pad-'+name,arguments.callee,false);
    return;
  }
  
  var dat = e.data;
//  console.log("received: "+dat);
  $('#pad-'+name).val(dat);
}, false);

var obj = $('#pad-'+name);
obj.keyup(function(e) {
  clearTimeout(padTimeouts[name]);
  padTimeouts[name] = setTimeout(function() 
  {
    var out = obj.val().replace(/\n/,"\ndata:")
//        console.log("val: "+obj.val());
//      console.log("sending: "+out);
    $.post('/pad', {name: name, msg: out});
  }, 150);

  e.preventDefault();
});
}

function clearBoard(name)
{
$.post('/board', {name: name, msg: "clear"});
}

function connectToBoard(name)
{
	var obj = $('#board-'+name);
var ctx = document.getElementById('board-'+name).getContext("2d");
ctx.lineWidth = 5;
ctx.lineCap = 'round';
ctx.lineJoin = 'round';

source.addEventListener('board-'+name, function(e) 
{
  if ($('#board-'+name).length == 0)
  {
    this.removeEventListener('board-'+name,arguments.callee,false);
    return;
  }
  if (e.data == "clear")
  {
    ctx.clearRect(0, 0, obj.width(), obj.height());
    ctx.beginPath();
    return;
  }
  
  var dat = e.data.split("x");
  var started = false;
  for (i=0; i < dat.length; i++)
  {
    var pts = dat[i].split(",");
    var x = parseFloat(pts[0]);
    var y = parseFloat(pts[1]);
    if (!started)
    {
      started = true;
      ctx.moveTo(x,y);
    }
    else
    {
      ctx.lineTo(x,y);
    }
  }
  ctx.stroke();
}, false);

obj.mouseup(function(e) {
  isDragging = false;

  $.post('/board', {name: name, msg: boards[name]});
  e.preventDefault();
});

obj.mousedown(function(e) {
  isDragging = true;
  pos = getPosition(e);
  var coord = pos.x+","+pos.y;
  boards[name] = coord;
  
  ctx.moveTo(pos.x,pos.y);
  e.preventDefault();
});

obj.mousemove(function(e) {
  if (isDragging)
  {
    pos = getPosition(e);
    var coord = pos.x+","+pos.y;
    boards[name] += "x"+coord;
    
    ctx.lineTo(pos.x,pos.y);
    ctx.stroke();
  }
  e.preventDefault();
});
}

buildChatWindow('chatter');