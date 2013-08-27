navigate = require './index'

# for caching data across navigation events
module.exports = class NavCache
  constructor: ->
    @cacheHash = []
    @cacheValue = {}

  set: (hash, value) ->
    index = navigate.index
    @cacheHash[index] = hash
    @cacheValue[hash] = value
    return

  get: (hash) ->
    index = navigate.index
    if @cacheHash[index] is hash
      @cacheValue[hash]



