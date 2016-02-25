#!/usr/bin/env ruby
## Bot, sits in TB server and pings periodically to
## remain connected. Parses SAY strings for globals

require 'socket'
require 'digest/md5'
require 'io/wait'

def resolver(server)
  puts "Trying to resolve #{server} to IP..."

  #Create our socket.
  host = 'game.toribash.com'
  port = 22000
  lobbySock = TCPSocket.new host, port

  #loop over lobby output
  while line = lobbySock.gets 
    if line =~ /^SERVER/
      line = line.split('; ')[1]
      line = line.split ' '
      if server == line[1]
        ip = line[0]
        puts "  => resolved #{server} to #{ip}"
        break
      end
    end
  end

  if !ip 
    puts "  => could not resolve #{server} to an IP"
  end

  lobbySock.close 

  #return ip
  ip
end

def redirecter(server)
  host = 'game.toribash.com'
  port = 22001 #Apparently port 22001 is what redirects me when I try to join a room
  sock = TCPSocket.new host, port

  sock.puts "join #{server}"

  while line = sock.gets
    if line =~ /^FORWARD/
      ip = line.split(';')[1]
      puts "  => got forwarded to #{ip}"
      break
    end
  end

  sock.close

  #return ip
  ip
end

def getIp(server)
  ip = resolver server
  if !ip
    ip = redirecter server
  end
  ip
end

def identify(user, pass, socket)
  digest = Digest::MD5.hexdigest pass
  socket.puts "NICK #{user}"
  socket.puts "mlogin #{user} #{digest}"
end

def setNick(nick)
  return 'NICK ' + nick
end

def login(nick, user, name)
  hostname = Socket.gethostname
  
  # Must prepend a colon to any strings that contain spaces.
  name = ':' + name

  # Construct the strings to send.
  arr = ['USER', nick, '0', '*', name]

  return arr.join(' ')
end 

def join_channel(channel)
  return 'JOIN ' + channel
end

server = 'idle'
user = 'foobot'
pass = 'password'
lastping = Time.new
quit = false

ip = getIp(server).split ':'
## I'm pretty sure this is a horror.
host, port = Socket.gethostbyaddr(ip[0].split('.').map! {|ele| ele.to_i }.pack('CCCC'))[0], ip[1]

puts "Connecting to socket: #{host}:#{port}"
socket = TCPSocket.new host, port.to_i
identify user, pass, socket
socket.puts 'SPEC'

host = 'irc.toribash.com'
port = 6667
channel = '#channel'

nickname = 'globalbot'
username = 'foobaaaat'
fullname = 'Just Foobot'
loggedIn = false

ircsock = TCPSocket.new host, port

if !loggedIn
  line = ircsock.gets

  ircsock.puts setNick(nickname) 
  ircsock.puts login(nickname, username, fullname) 
  ircsock.puts "MODE #{nickname} +B"
  ircsock.puts join_channel(channel)

  loggedIn = true
end 

loop do
  break if quit

  #sleep so as to not kill cpu.
  sleep 1

  #make sure tb doesn't ping out.
  delta = Time.new.to_i - lastping.to_i
  if delta >= 30
    # puts "delta: #{delta}, pinging..."
    socket.puts 'PING'
    lastping = Time.new
  end

  if ircsock.ready?
    line = ircsock.gets
    #Make sure irc doesn't ping out.
    if line and line.start_with? 'PING'
      pong = 'PONG ' + line.split(' ')[1]
      puts "pinging irc..."
      ircsock.puts pong
    end
  end
  
  if socket.ready?
    line = socket.gets
    if line.start_with? 'SAY 0; [global]'
      line = line.split('[global] ')[1]
      ircsock.puts "PRIVMSG #{channel} :#{line}"
    end
  end
end

ircsock.close
socket.close
