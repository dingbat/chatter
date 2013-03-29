#!/usr/bin/env ruby -I ../lib -I lib
# coding: utf-8
require 'sinatra'
set :server, 'thin'
connections = []

get '/' do
  halt erb(:login) unless params[:user]
  erb :chat, :locals => { :user => params[:user].gsub(/\W/, '') }
end

get '/stream', :provides => 'text/event-stream' do
  stream :keep_open do |out|
    connections << out
    out.callback { connections.delete(out) }
  end
end

post '/chat' do
  payload = "event: chat-#{params[:name]}\ndata: #{params[:user]}\ndata: #{params[:msg]}\n\n"
  connections.each { |out| out << payload }
  204 # response without entity body
end

post '/pad' do
  connections.each { |out| out << "event: pad-#{params[:name]}\ndata: #{params[:msg]}\n\n" }
  204 # response without entity body
end

post '/board' do
  connections.each { |out| out << "event: board-#{params[:name]}\ndata: #{params[:msg]}\n\n" }
  204 # response without entity body
end

__END__

@@ layout
<html>
  <head>
    <title>Super Simple Chat with Sinatra</title>
    <meta charset="utf-8" />
    <script src="http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js"></script>
  </head>
  <body><%= yield %></body>
</html>

@@ login
<form action='/'>
  <label for='user'>User Name:</label>
  <input name='user' value='' />
  <input type='submit' value="GO!" />
</form>

@@ chat
<div id="rooms"></div>

<br>
<br>
<br>

<div id="pads"></div>
<br>
<br>
<br>

<div id="boards"></div>

<br>
<br>
<br>
New Room: <input id="rname" /><button onclick="newRoom($('#rname').val())">go</button>
<br>
New Pad: <input id="pname" /><button onclick="newPad($('#pname').val())">go</button>
<br>
New Board: <input id="bname" /><button onclick="newWhiteboard($('#bname').val())">go</button>

<script>
  padTimeouts = {};
  boardTimeouts = {};
  boards = {};
  isDragging = false;
  
  source = new EventSource('/stream?str='+name);
  
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

  function newRoom(name)
  {
    $('#rooms').append("<pre id='chat-"+name+"'></pre><form id='form-"+name+"'><input id='msg-"+name+"' placeholder='type message here...' /></form>");
    
    source.addEventListener('chat-'+name, function(e) 
    {
      var dat = e.data.split("\n"); 
      var user = dat[0];
      var msg = dat[1];
      $('#chat-'+name).append("\n" + "<b>" + user + "</b>: "+msg);
    }, false);
    
    $('#form-'+name).on('submit',function(e) {
      var msgBox = $('#msg-'+name);

      $.post('/chat', {name: name, msg: msgBox.val(), user: "<%= user %>"});
      msgBox.val('');
      msgBox.focus();
      e.preventDefault();
    });
  }
  
  function newPad(name)
  {
    $('#pads').append("<textarea id='pad-"+name+"' />");
    
    source.addEventListener('pad-'+name, function(e) 
    {
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
  
  function newWhiteboard(name)
  {
    $('#boards').append("<canvas style='border: 1px solid black;' id='board-"+name+"' width='400' height='250'></canvas><button onclick='clearBoard(\""+name+"\")'>clr</button>");
		
		var obj = $('#board-'+name);
    var ctx = document.getElementById('board-'+name).getContext("2d");
    ctx.lineWidth = 5;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    
    source.addEventListener('board-'+name, function(e) 
    {
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
  newRoom("room");
</script>
