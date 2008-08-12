# Copyright (c) 2008 James Smith (www.floppy.org.uk)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# http://www.opensource.org/licenses/mit-license.php

dir = File.dirname(__FILE__) + '/../lib'
$LOAD_PATH << dir unless $LOAD_PATH.include?(dir)

require 'rubygems'
require 'log4r'
require 'yaml'

require 'jabberstatus/jabber_status_bot'

# Load config file
config = YAML.load_file("#{File.dirname(__FILE__)}/../config/config.yml")
XMPP_JID = config['jabber_id']
XMPP_PASSWORD = config['jabber_password']
TWITTER_CRYPT_KEY = config['twitter_crypt_key']
TWITTER_CRYPT_IV = config['twitter_crypt_iv']
FB_API_KEY = config['facebook_api_key']
FB_API_SECRET = config['facebook_api_secret']
ADMIN_JID = config['admin_jid']

# Create logger
log = Log4r::Logger.new 'log'
log.outputters = Log4r::Outputter.stdout
log.level = config['debug_mode'] == true ? Log4r::DEBUG : Log4r::ERROR
Jabber.debug = log.debug?

log.debug "Creating jabber bot"
bot = JabberStatusBot.new(:log => log, :mainthread => Thread.current)

log.debug "Initialisation complete - ready for commands"
Thread.stop

log.debug "Exiting"
bot.close