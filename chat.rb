#!/usr/bin/env ruby -I ../lib -I lib
# coding: utf-8
require 'sinatra'
set :server, 'thin'
connections = []
chats = {}

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
    <link rel="stylesheet" type="text/css" href="jquery-ui.css"/>
    <link rel="stylesheet" type="text/css" href="style.css" />
    </head>
  <body><%= yield %></body>
</html>

@@ chat

<section class="sidebar">
  <div class="inset">
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
  <div class="inset">
    <div id="windows">
    </div>
  </div>
</section>

<script src="js.js"></script>