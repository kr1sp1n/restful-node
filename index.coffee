# api.coffee

express = require 'express'
request = require 'request'
async = require 'async'

app = express.application

app.register = (sns, endpoint, service_id)->
  request
    uri: sns + '/service_instance'
    method: 'POST'
    json:
      endpoint: endpoint
      service_id: service_id
  , (err, response, body)->
    console.error err if err?

app.resource = (name, actions, params)->
  @resources ?= {} 
  res = @resources[name] = 
    id: name
    name: name
    type: 'resource'
    actions: actions
    params: params
    properties: {}

  res.property = (name, type, action)=>
    res.properties[name] = 
      type: type
      action: (req, res)->
        return (next)->
          action(req, res, next)
    
  return res

api = express()

api.engine 'json', require('ejs').renderFile
api.set 'views', __dirname + '/lib/views'
api.set 'view engine', 'json'
api.set 'port', 8080

api.use express.bodyParser()

getEndpoint = (req)->
  return req.protocol + "://" + req.get('host')

getItemHref = (req, resource, id)->
  return getEndpoint(req) + "/" + resource + "/" + id
 
# simple logger
api.use (req, res, next)->
  # TODO - make logging configurable
  #console.log '%s %s', req.method, req.url
  next()

# set global response header
api.use (req, res, next)->
  res.set 'Content-Type', 'application/json'
  res.header "Access-Control-Allow-Origin", "*"
  res.header "Access-Control-Allow-Headers", "Content-Type, Authorization, Content-Length, X-Requested-With"
  next()

# route handling
api.use api.router

# error handling
api.use (err, req, res, next)->
  res.render 'error', { code: res.statusCode, message: err.message, param: err.param } 

# global logic for all resources
api.all '/:resource*', (req, res, next)->
  id = req.path.split('/')[2]? and req.path.split('/')[2] != ''

  method = do =>
    return 'index' if req.method == 'GET' and not id 
    return 'show' if req.method == 'GET' and id 
    return 'create' if req.method == 'POST' and not id
    return 'update' if req.method == 'PUT' and id
    return 'delete' if req.method == 'DELETE' and id
    return 'options' if req.method == 'OPTIONS'
   
  actions = api.resources[req.params.resource].actions

  allow_methods= do->
    result = []
    result.push 'GET' if actions['index'] and not id
    result.push 'GET' if actions['show'] and id
    result.push 'POST' if actions['create'] and not id
    result.push 'PUT' if actions['update'] and id
    result.push 'DELETE' if actions['delete'] and id
    result.push 'OPTIONS'
    return result

  res.header 'Access-Control-Allow-Methods', allow_methods.join(',')
  res.header 'Allow', allow_methods.join(',')

  # response available params
  if method == 'options'
    res.locals.items = do->
      result = []
      params = api.resources[req.params.resource].params['index'] if not id
      for name of params
        result.push
          id: name
          name: name
          description: params[name]
          type: 'parameter'

      return result 

    return render(req, res, next) 

  unless api.resources[req.params.resource]?
    res.status(404)
    return next new Error('Resource Not Found')

  unless actions[method]?
    res.status(501)
    return next new Error('Method Not Implemented')

  next()


# return associated resources
api.get '/', (req, res)->
  resources = []
  for name of api.resources
    resource = api.resources[name] 
    item =
      id: resource.id
      name: resource.name
      type: "resource"
      href: getEndpoint(req) + "/" + resource.name 
    resources.push item 

  res.render 'default',
    total: resources.length
    items: resources

getProperties = (req, res)->
  return (item, done)->
    res.locals.item = item
    properties = api.resources[item['type']]?.properties
    if properties
      f = {}
      for property of properties
        f[property] = properties[property].action(req, res)

      async.parallel f, (err, result)->
        for key of result
          if result[key].length?
            result[key].forEach (x)->
              x['type'] = properties[key].type
              x['href'] = getItemHref(req, x['type'], x.id) if x.id? 
          item[key] = result[key]
        done()
    else
      done()

extendItems = (req, res, next)->
  res.locals.items = res.locals.items.map (item)->
    item['type'] = req.params.resource
    item['href'] = getItemHref(req, item['type'], item.id) if item.id?
    return item
  next()

refItems = (req, res, next)->
  async.each res.locals.items, getProperties(req, res), next 

render = (req, res, next)->
  unless res.locals.total? then res.locals.total = res.locals.items.length
  res.render 'default',
    total: res.locals.total
    items: res.locals.items


# return a list of items by a filter 
api.get '/:resource', [
  (req, res, next)->
    api.resources[req.params.resource].actions.index req, res, (err, items)->
      res.locals.items = items
      next err

  extendItems
  refItems
  render
]
   

# return exactly one item by its id
api.get '/:resource/:id', [
  (req, res, next)->
    api.resources[req.params.resource].actions.show req, res, (err, items)->
      res.locals.items = items
      next err
  extendItems
  refItems
  render
]


# create new item in resource list
api.post '/:resource', [
  (req, res, next)->
    api.resources[req.params.resource].actions.create req, res, (err, items)->
      res.locals.items = items
      next err

  extendItems
  refItems
  render
]


# update resource item by id
api.put '/:resource/:id', [
  (req, res, next)->
    api.resources[req.params.resource].actions.update req, res, (err, items)->
      res.locals.items = items
      next err
  
  extendItems
  refItems
  render
]


# delete resource item by id
api.delete '/:resource/:id', [
  (req, res, next)->
    api.resources[req.params.resource].actions.delete req, res, (err, items)->
      res.locals.items = items
      next err
  extendItems
  refItems
  render
]
  

unless module.parent?
  api.listen api.get 'port'

module.exports = api
