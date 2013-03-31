#!/usr/bin/env ruby -I ../lib -I lib
# coding: utf-8
require 'sinatra'
set :server, 'thin'
connections = []
chats = {}

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

get '/chat' do
  chats[params[:name]]
end

post '/chat' do
  name = params[:name]
  user = params[:user]
  msg = params[:msg]
  
  chats[name] ||= ""
  chats[name] += "<b>"+user+"</b>: "+msg+"\n"
  
  payload = "event: chat-#{name}\ndata: #{user}\ndata: #{msg}\n\n"
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
    <title>Chatter</title>
    <meta charset="utf-8" />
    <script src="jquery-1.9.1.js"></script>
    <script src="jquery-ui.js"></script>
    <link rel="stylesheet" type="text/css" href="http://ajax.googleapis.com/ajax/libs/jqueryui/1.7.1/themes/base/jquery-ui.css"/>
    <link rel="stylesheet" type="text/css" href="style.css" />
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

<section class="sidebar">
  <div class="inset">
    <h1>chatter</h1>
    <br>

  <a href="#" onclick="makeBox('room')">new room</a>
  <br>
  <a href="#" onclick="makeBox('pad')">new pad</a>
  <br>
  <a href="#" onclick="makeBox('board')">new board</a>
  </div>
</section>

<section class="main">
  <div class="inset">
    <div id="windows">
    </div>
  </div>
</section>

<script>
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
    var a = "<div id='window-"+name+"' class='window'> \
      <div class='titlebar'><div class='title'>chatroom</div><div class='kill'>x</div></div> \
      <div class='content'> \
        <pre id='chat-"+name+"' class='chatbox'></pre> \
        <form id='form-"+name+"'><input id='msg-"+name+"' placeholder='type message here...' /></form> \
      </div> \
    </div> \
    ";
    
    $('#windows').append(a);
    
    $('#window-'+name).draggable();
    $('#window-'+name).resizable();
    
    console.log("add listener for chat-"+name);
    source.addEventListener('chat-'+name, function(e) 
    {
      var dat = e.data.split("\n"); 
      var user = dat[0];
      var msg = dat[1];
      $('#chat-'+name).append("<b>" + user + "</b>: "+msg+"\n");

      console.log("being chatted at by "+user);

    }, false);
    
    $('#form-'+name).on('submit',function(e) {
      var msgBox = $('#msg-'+name);

      $.post('/chat', {name: name, msg: msgBox.val(), user: "<%= user %>"});
      msgBox.val('');
      msgBox.focus();
      e.preventDefault();
    });
    
    $.get('/chat?name='+name, function(data)
    {
      $('#chat-'+name).html(data);
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
