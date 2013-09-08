Uri = require 'uri-fork'
require 'debug-fork'
debug = global.debug 'ace:navigate'
{include} = require 'lodash-fork'

replaceInterval = 2000
replaceLastCall = 0
replaceTimeoutId = 0

uris = []
routeFn = null
routeCtx = null
useHash = null
iframe = null
currentUri = null

include Uri,

  hasHashPath: do ->
    regex = /^#\d+/
    -> regex.test @hash

  index: do ->
    regex = /^#(\d+)/
    -> +tmp if tmp = @hash.match(regex)?[1]

  hasPath: -> @path.length > 1

  hashPath: do ->
    regex = /^#\d+(\/[^#]*)/
    -> @hash.match(regex)?[1] || '/'

  hashHash: do ->
    regex = /^#.*?(#.*)$/
    -> @hash.match(regex)?[1] || ''

  stripHashPath: ->
    @setPath @hashPath() if @hasHashPath()
    @setHash @hashHash()
    this

  hashUri: (index) ->
    "##{index}#{@path}#{@hash}"

module.exports = navigate = (uri) ->
  uri = new Uri uri, navigate.uri unless uri instanceof Uri
  if uri.uri isnt navigate.uri.uri
    if uri.pathname is navigate.uri.pathname
      replaceThrottled uri
    else
      push uri
  return

navigate.index = 0

listen = (event, fn) ->
  if window.addEventListener
    window.addEventListener event, fn
  else if window.attachEvent
    window.attachEvent "on#{event}", fn
  return

doReplace = (now=new Date) ->
  replaceLastCall = now
  replaceTimeoutId = null

  debug "REPLACE"
  currentUri = navigator.uri

  if useHash
    hash = navigate.uri.hashUri(navigate.index)
    window.location.replace hash
    iframe?.location.replace hash

  else
    window.history.replaceState navigate.index, '', navigate.uri.uri

  return

navigate.replaceNow = replace = (uri) ->
  clearTimeout replaceTimeoutId if replaceTimeoutId?
  uris[navigate.index] = navigate.uri = uri
  doReplace()
  return

navigate.replace = replaceThrottled = (uri) ->
  uri = new Uri uri unless uri instanceof Uri
  uris[navigate.index] = navigate.uri = uri

  now = new Date
  remaining = replaceInterval - (now - replaceLastCall)

  if remaining <= 0
    clearTimeout replaceTimeoutId if replaceTimeoutId?
    doReplace now
  else unless replaceTimeoutId?
    replaceTimeoutId = setTimeout doReplace, replaceInterval

  return

navigate.push = push = (uri) ->
  uri = new Uri uri unless uri instanceof Uri

  if replaceTimeoutId?
    clearTimeout replaceTimeoutId
    doReplace()

  currentUri = uris[++navigate.index] = navigate.uri = uri

  debug "PUSH"

  if useHash
    iframe?.document.open().close()
    window.location.hash = uri.hashUri(navigate.index)
    iframe?.location.href = window.location.href
  else
    window.history.pushState navigate.index, '', uri.uri

  return

locationchange = ->
  newUri = new Uri window.location.href

  if newUri.hasHashPath()
    newIndex = newUri.index()
    newUri.stripHashPath()
  else unless useHash
    newIndex = window.history.state

  if !newIndex? or (newIndex is navigate.index and currentUri and newUri.uri isnt currentUri.uri)
    newIndex = uris.length
    uris[newIndex] = newUri
    replaceWith = newUri if useHash

  if newIndex isnt navigate.index
    if replaceTimeoutId?
      clearTimeout replaceTimeoutId
      replaceTimeoutId = null

    navigate.index = newIndex

    debug "Got location change from #{navigate.uri} to #{newUri}"

    storedUri = uris[newIndex]

    if (replaceWith ||= if storedUri and storedUri.uri isnt newUri.uri then storedUri else null)
      replace replaceWith
    else
      navigate.uri = uris[newIndex] = newUri

    routeFn.call routeCtx, navigate.uri, navigate.index

    debug "Done with locationchange"
  return

module.exports.enable = ->
  unless navigate.uri

    if /msie [\w.]+/.exec(window.navigator.userAgent.toLowerCase()) and (document.documentMode || 0) <= 7
      iframe = $('<iframe src="javascript:0" tabindex="-1" />').hide().appendTo('body')[0].contentWindow
      iframe.location.href = window.location.href

    currentUri = navigate.uri = new Uri window.location.href

    if useHash = !window.history || !window.history.pushState
      navigate.index = navigate.uri.index()
    else
      navigate.index = window.history.state

    navigate.index ||= 0
    uris[navigate.index] = navigate.uri

    navigate.uri.stripHashPath() if navigate.uri.hasHashPath()
    doReplace() unless useHash

    if iframe
      setInterval (->
        if iframe.location.href isnt window.location.href
          window.location.href = iframe.location.href
          locationchange()
      ), 300

    else if useHash
      listen 'hashchange', locationchange
    else
      listen 'popstate', locationchange

  return


module.exports.listen = (route, ctx) ->
  module.exports.enable() unless navigate.uri

  unless routeFn
    routeFn = route
    routeCtx = ctx

  else
    currentRoute = routeFn
    currentRouteCtx = routeCtx

    routeCtx = null

    routeFn = (uri, index) ->
      currentRoute.call currentRouteCtx, uri, index
      route.call ctx, uri, index
      return

  navigate
