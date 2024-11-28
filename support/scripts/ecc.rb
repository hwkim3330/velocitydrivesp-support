#!/usr/bin/env ruby

# Copyright (c) 2021-2022 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require 'pp'
require 'open3'
require 'thread'
require 'optparse'
require 'fileutils'
#require '/home/henrikb/.rvm/gems/ruby-2.6.1/gems/coap-0.1.4/lib/coap.rb'
require 'ipaddress'
require 'coap'
require 'json'
require 'cbor-pure'

$opt = { }
OptionParser.new do |opts|
    opts.banner = "Usage: #{$0}"

    opts.on("-i", "--ip IP", "IP address of Dut") do |i|
        $opt[:ip] = i
    end

    opts.on("-p", "--port Port", "The UDP D-port") do |p|
        $opt[:port] = p
    end

    opts.on("-d", "--ds <c|c-sid|s>", "Data store, default to c") do |d|
        $opt[:ds] = d
    end

    opts.on("-s", "--sid SID", "SID as numeric value") do |s|
        $opt[:sid] = s
    end

    opts.on("-m", "--method <get|put|post|del>", "CoAP method to use") do |m|
        $opt[:method] = m
    end

    opts.on("-t", "--test ", "CoAP test") do |t|
        $opt[:test] = t
    end
end.parse!

if $opt[:ip].nil?
  puts "--ip parameter missing"
  exit -1
end

if $opt[:port].nil?
  puts "--port parameter missing"
  exit -1
end

if $opt[:ds].nil?
    $opt[:ds] = "c" #Default data store is c
end

if $opt[:sid].nil?
  puts "--sid parameter missing"
  exit -1
end

if $opt[:method].nil?
  puts "--method parameter missing"
  exit -1
end

if !IPAddress::valid? $opt[:ip]
  puts "--ip parameter invalid"
  exit -1
end

if $opt[:ds] != "c"
  puts "--ds parameter invalid"
  exit -1
end

methods = ["get", "put", "post", "del"]
if !methods.include?($opt[:method])
  puts "--method parameter invalid"
  exit -1
end

puts "Parse of parameters done"

def sid_encode (sid)
# Base64 urlsafe encoding table
# clang-format off
    base64_urlsafe = [
    'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
    'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
    'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
    'w','x','y','z','0','1','2','3','4','5','6','7','8','9','-','_']
# clang-format on

    buf = ""
    save = false
    i = 60
    j = 0
    n = 0
    while i >= 0 do
        n = (sid >> i) & 0x3f
#puts "i #{i} n #{n}  save #{save}"
        if (n != 0)
            save = true # Start saving after first non zero data
        end
        if (save)
            buf = buf + base64_urlsafe[n]
        end

        i -= 6
    end
    return buf
end

path = "/#{$opt[:ds]}/" + sid_encode($opt[:sid].to_i)
if !$opt[:test].nil?
    if $opt[:test] == '1'
        path = "/#{$opt[:ds]}/" + "Bth"
    end
end

command = "coap-client -m get -A 60 coap://#{$opt[:ip]}:#{$opt[:port].to_i}#{path}"
if !$opt[:test].nil?
    if $opt[:test] == '2'
        command = "coap-client -m get -A 60 -b #{10*16} coap://#{$opt[:ip]}:#{$opt[:port].to_i}#{path}"
    end
end

puts "command #{command}"

Open3::popen3(command) do |i, o, e, t|
    i.close
    e.each do |e|
        puts "Error #{e}"
    end
    o.each do |l|
        #Remove some extra bytes that is not CBOR
        response = l.unpack('H*')
        response1 = response[0][0..-3]
        response[0] = response1

        #Decode the CBOR to Hash
        out = CBOR.decode(response.pack('H*'))
#puts "****out[7026][0][134] #{out[7026][0][134]}"
#puts "****out[7026][0][3] #{out[7026][0][3]}"
#puts "****out #{out}"
        pp out
    end
end
