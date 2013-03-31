padTimeouts = {};
boardTimeouts = {};
boards = {};
isDragging = false;
totalWindows = 0;

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
var a = "<div class='chatbox'><pre id='chat-"+name+"'></pre> \
<form action='javascript:;' id='form-"+name+"'><input size='40' id='msg-"+name+"' autocomplete='off' placeholder='type message here...' /></form></div>";
return a;
}

function padCode(name)
{
var a = "<textarea id='pad-"+name+"' style='width:100%; height:100%; resize: none; border: none;' />";
return a;
}

function boardCode(name)
{
var a = "<canvas style='border-bottom: 1px solid black; background-color:white;' id='board-"+name+"' width='400' height='250'></canvas><div class='toolbar handler'><button onclick='clearBoard(\""+name+"\")'>clear</button></div>";
return a;
}

function buildChatWindow(name)
{
var a = chatCode(name);
makeWindow('window-room-'+name, name+' room',a, false);
connectToRoom(name);
}

function buildPadWindow(name)
{
var a = padCode(name);
makeWindow('window-pad-'+name, name+' pad',a, false);
connectToPad(name);
}

function buildBoardWindow(name)
{
var a = boardCode(name);
makeWindow('window-board-'+name, name+' board',a, true);
connectToBoard(name);
}

function newWindow(type, wind, name)
{
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
var win = $(x).parents(".window");
win.remove();
}

function makeWindow(id, title, content, board)
{
	totalWindows++;
	
	var x = totalWindows*15;
var a = "<div id='"+id+"' class='window' style='left:"+x+"px; top:"+x+"px; "+(board ? "width: 400px; height: 280px" : "width: 250px")+"'> \
  <div class='titlebar handler'><div class='title'>"+title+"</div><div class='kill'><a href='#' style='text-decoration:none' onclick='killWindow(this)'>x</a></div></div> \
  <div class='content'> \
  "+content+" \
  </div> \
</div> \
";

$('#windows').append(a);

$('#'+id).draggable({ cursor: "move", stack: "#windows div", scroll:false, containment: "parent", handle: ".handler"});

if (!board)
{
  $('#'+id).resizable();
}
}

function joinWindow(type, form)
{
	var name = $(form).find('#namefield').val();
	var wind = $(form).parents(".window");
	
	if ($('#window-'+type+"-"+name).length > 0)
	{
		wind.find('.newcontent').append("<div class='dupealert'>"+name+" "+type+" is already open.</div>");
	}
	else
	{
		newWindow(type, wind, name);
	}
}

function makeBox(type)
{
var a = "<div class='newtext'> \
<div class='newcontent'> \
	<form action='javascript:;' onsubmit='joinWindow(\""+type+"\", this)'> \
    create/join "+type+":<br> \
    <input id='namefield' placeholder='"+type+" name' /><br> \
    <button id='temp-btn'>go!</button> \
	</form> \
</div> \
</div>";

makeWindow('temp-win', 'new '+type, a, type=="board");
$('#temp-win').find('#namefield').focus();
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
	var disp = "<b>"+user+"</b>: ";
  var msg = dat[1];
	if (user == $('#user').val())
	{
		disp = "<span style='color:blue'>"+disp+"</span>";
	}
  $('#chat-'+name).append(disp+msg+"\n");

}, false);

$('#form-'+name).on('submit',function(e) {
  var msgBox = $('#msg-'+name);
	if (msgBox.val().length == 0)
		return;

  var user = $('#user').val();
  if (user.length == 0)
  {
    user = "anon";
  }
  $.post('/chat', {name: name, msg: msgBox.val(), user: user});
  msgBox.val('');
  msgBox.focus();
	var scrolly = msgBox.parent(".content");
	scrolly.scrollTop(scrolly[0].scrollHeight);
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

$.get('/pad?name='+name, function(data)
{
	$('#pad-'+name).val(data);
});
}

function clearBoard(name)
{
$.post('/board', {name: name, msg: "clear"});
}

function drawBoardData(ctx, data)
{
	var chunks = data.split("|");
	for (a = 0; a < chunks.length; a++)
	{
		var chunk = chunks[a];
		if (chunk.length == 0 || !chunk)
		{
			break;
		}
		var dat = chunk.split("x");
		  var started = false;
		  for (i=0; i < dat.length; i++)
		  {
		    var pts = dat[i].split(",");
		    var x = parseInt(pts[0]);
		    var y = parseInt(pts[1]);
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
	}
}

function sendBoardData(name)
{
	if (boards[name])
	{
		isDragging = false;
	  	$.post('/board', {name: name, msg: boards[name]+"|"});
	}
}

function connectToBoard(name)
{
	var obj = $('#board-'+name);
var ctx = document.getElementById('board-'+name).getContext("2d");
ctx.lineWidth = 5;
ctx.lineCap = 'round';
ctx.lineJoin = 'round';

$.get('/board?name='+name, function(data)
{
	if (data.length > 0)
	{
		drawBoardData(ctx, data); 
	}
});

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

  drawBoardData(ctx, e.data);
}, false);

obj.mouseup(function(e) {
	sendBoardData(name);
  e.preventDefault();
});

obj.mouseout(function(e) {
	sendBoardData(name);
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
//make the first window on bottom? seems to come up for some reason
//$('#window-room-chatter').attr('z-index', undefined);
