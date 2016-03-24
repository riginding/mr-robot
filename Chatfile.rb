require 'robut/storage/yaml_store'
require 'robut/plugin/help'
require 'yaml'

class Robut::Plugin::Mahlzeit
  include Robut::Plugin

  # Returns a description of how to use this plugin
  def usage
    [
      "#{at_nick} mahlzeit - #{nick} fragt wer zu Mittag fahren will",
      "#{at_nick} stats - #{nick} sendet dir deine Statistik",
      "#{at_nick} ich - #{nick} fuegt dich zur Liste hinzu",
    ]
  end

  # Replies with a random string selected from +places+.
  def handle(time, sender_nick, message)
    words = words(message)
    phrase = words.join(' ')

    puts phrase
    if sent_to_me?(message)
      puts "hier"
      if phrase == "mahlzeit"
        puts "1"
        mahlzeit()
      elsif phrase == "stats"
        puts "2"
        stats(sender_nick)
      elsif phrase == "ich" && store["lunchtime"]
        puts "3"
        add( sender_nick )
      end
    end
  end

  def mahlzeit
    return if store["lunchtime"]

    store["lunchtime"] = true
    store["wants_to_go"] = []

    reply "Mahlzeit! Wer möchte mit fahren? Schreibe '#{at_nick} ich' in den nächsten 10 Minuten wenn du mitfahren möchtest."

    Thread.new do
      sleep 10
      time_up
    end
  end

  def stats(nick)
    if store[nick]
      reply "#{nick} ist schon #{store[nick]["driven"]} mal Fahrer gewesen, und #{store[nick]["joined"]} mal mitgefahren."
    else
      reply "#{nick} hat noch keine Statistiken."
    end
  end

  def time_up
    puts "in time up"
    gang = store["wants_to_go"].join(", ")
    puts "hallo  #{gang}"
    drivers = pick_drivers
    puts "test #{drivers}"

    reply "#{gang} fahren mit."
    reply "#Es werden {count_cars} Auto(s) benötigt." if count_cars > 1
    if drivers.count > 1
      reply "Heute fahren #{drivers.join(', ')}"
    else
      reply "Heute fährt #{drivers.first}"
    end

    store["lunchtime"] = false
    store["wants_to_go"] = []
  end

  def pick_drivers
    puts "in pick_drivers"
    driver = []

    ratios = store["wants_to_go"].inject do |ratio, d|
      result[store[d][ratio]] ||= []
      result[store[d][ratio]] << d
    end
    puts "ratios, #{ratios}"

    sorted = ratios.keys.sort
    puts "sorted, #{sorted}"

    i=0
    while i < count_cars
      pick = ratios[ sorted.first ].shuffle.first

      ratios[ sorted.first ].delete( pick )
      if ratios[ sorted.first ].length == 0
        ratios.delete( sorted.first )
        sorted.delete( sorted.first )
      end

      driver << pick
      i += 1
    end

    driver.each do |d|
      set_pick(d)
    end

    driver
  end

  def set_pick(nick)
    store[nick]["driven"] += 1
  end

  def count_cars
    if store["wants_to_go"].length % 5 == 0
      store["wants_to_go"].length / 5
    else
      store["wants_to_go"].length / 5 + 1
    end
  end

  def ratio(nick)
    if store[nick]["driven"] == 0
      store[nick]["ratio"] = 0
    else
      store[nick]["ratio"] = store[nick]["driven"].to_f / store[nick]["joined"].to_f
    end
  end

  def add(nick)
    store[nick] ||= {"driven" => 0, "joined" => 0}
    store[nick]["joined"] += 1
    store[nick]["ratio"] = ratio(nick)

    reply "#{nick} will mitfahren!"
  end

  def join(nick)
    store["wants_to_go"] = store["wants_to_go"] + Array(nick)
  end
end

def load_configs
  conf = YAML.load_file( "robot.yml" )
  conf['dm_hipchat']
end

Robut::Plugin.plugins << Robut::Plugin::Help
Robut::Plugin.plugins << Robut::Plugin::Mahlzeit

Robut::Connection.configure do |config|
  # Note that the jid must end with /bot if you don't want robut to
  # spam the channel, as described by the last bullet point on this
  # page: https://www.hipchat.com/help/category/xmpp

  conf = load_configs
  config.jid = conf['jid']
  config.password = conf['password']
  config.nick = conf['nick']
  config.room = conf['room']

  # Custom @mention name
  # config.mention_name = 'Bot'

  # Ignore personal messages
  # config.enable_private_messaging = false

  # Some plugins require storage
  Robut::Storage::YamlStore.file = ".robut"
  config.store = Robut::Storage::YamlStore

  # Add a logger if you want to debug the connection
  #config.logger = Logger.new(STDOUT)
end
