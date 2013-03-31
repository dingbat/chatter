#!/usr/bin/env ruby -I ../lib -I lib
# coding: utf-8
require 'sinatra'
set :server, 'thin'
connections = []

chats = {}
boards = {}
pads = {}

get '/' do
  erb :chat
end

get '/stream', :provides => 'text/event-stream' do
  stream :keep_open do |out|
    connections << out
    out.callback { connections.delete(out) }
  end
end

get '/chat' do
  chats[params[:name]] || ""
end

get '/board' do
  puts "sending "+ (boards[params[:name]] || "")
  boards[params[:name]] || ""
end

get '/pad' do
  pads[params[:name]] || ""
end

post '/chat' do
  name = params[:name]
  user = params[:user]
  msg = params[:msg]
  
  chats[name] ||= ""
  chats[name] += "<b>"+user+"</b>: "+msg+"<br>"
  
  payload = "event: chat-#{name}\ndata: #{user}\ndata: #{msg}\n\n"
  connections.each { |out| out << payload }
  204 # response without entity body
end

post '/pad' do
  name = params[:name]
  msg = params[:msg]

  pads[name] = msg

  connections.each { |out| out << "event: pad-#{name}\ndata: #{msg}\n\n" }
  204 # response without entity body
end

post '/board' do
  name = params[:name]
  msg = params[:msg]
  
  puts "adding #{msg} to baords[#{name}]"
  
  if msg
    if msg == "clear"
      boards[name] = ""
    else
      boards[name] ||= ""
      boards[name] += msg
    end
  end
  
 # puts "boards[#{name}] = #{boards[name]}"
  
  connections.each { |out| out << "event: board-#{name}\ndata: #{msg}\n\n" }
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
    <link rel="stylesheet" type="text/css" href="jquery-ui.css"/>
    <link rel="stylesheet" type="text/css" href="style.css" />
    </head>
  <body><%= yield %></body>
</html>

@@ chat

<section class="sidebar">
  <div class="insetside">
    <h1>chatter</h1>
    
    <br>
    <a href="#" onclick="buildChatWindow('csc252')">csc252</a>
    <br><br>
    
    <hr>
    
    <br>
    <a href="#" onclick="makeBox('room')">new room</a>
    <br>
    <a href="#" onclick="makeBox('pad')">new pad</a>
    <br>
    <a href="#" onclick="makeBox('board')">new board</a>
    <br><br>
  
    <hr>
  
    <br>
    <b>username:</b><br>
    <input id="user" placeholder="anon" />
  </div>
</section>

<section class="main">
  <div id="windows">
  </div>
</section>

<script src="js.js"></script>