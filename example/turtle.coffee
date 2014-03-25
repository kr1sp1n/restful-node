# example/turtle.coffee
# Silly test service
#

api = require "#{__dirname}/../index"
api.set 'port', 8080

turtles = [
  { id: 'leo', name: 'Leonardo', color: 'blue', weapon: 'ninjakens' }
  { id: 'mike', name: 'Michelangelo', color: 'orange', weapon: 'nunchakus' }
  { id: 'don', name: 'Donatello', color: 'purple', weapon: 'bo staff' }
  { id: 'raph', name: 'Raphael', color: 'red', weapon: 'sais' }
]

turtleHandler =
  index: (req, res, next)->
    next null, JSON.parse(JSON.stringify(turtles))

  show: (req, res, next)->
    s = turtles.filter (item)->
      String(item.id) == String(req.params.id)
    next null, JSON.parse(JSON.stringify(s))

  create: (req, res, next)->
    name = req.body.name
    id = name.toLowerCase()
    color = req.body.color
    weapon = req.body.weapon
    item = { id: id, name: name, color: color, weapon: weapon }
    turtles.push item
    next null, [ item ]


tmnt = api.resource 'teenage_mutant_ninja_turtle', turtleHandler

api.listen api.get 'port'
console.log "Listening on #{api.get 'port'}"
