Url = require '../url'
debug = global.debug 'ace:navigate'
{include} = require '../mixin'

replaceInterval = 2000
replaceLastCall = 0
replaceTimeoutId = 0

urls = []
routeFn = null
routeCtx = null
ignoreCount = 0
useHash = null
iframe = null

include Url,

  hasHashPath: do ->
    regex = /^#\d+/
    -> @hash and regex.test @hash

  index: do ->
    regex = /^#(\d+)/
    ->
      if (tmp = @hash and regex.exec(@hash)?[1])
        +tmp

  hasPath: -> @path.length > 1

  hashPath: do ->
    regex = /^#\d+(\/[^#]*)/
    -> @hash?.match(regex)?[1] || '/'

  hashHash: do ->
    regex = /^#.*?#(.*)$/
    -> @hash?.match(regex)?[1]

  stripHashPath: ->
    @reform
      hash: @hashHash() || ''
      path: if @hasHashPath() then @hashPath() else @path

  hashHref: ->
    "##{index}#{@path}#{@hash || ''}"

module.exports = navigate = (url) ->
  url = new Url url, navigate.url unless url instanceof Url
  if url.href isnt navigate.url.href
    if url.pathname is navigate.url.pathname
      replaceThrottled url
    else
      push url
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

  if useHash
    hash = navigate.url.hashHref()

    ++ignoreCount
    window.location.replace hash
    iframe?.location.replace hash

  else
    window.history.replaceState navigate.index, '', navigate.url.href

  return

replace = (url) ->
  clearTimeout replaceTimeoutId if replaceTimeoutId?
  urls[navigate.index] = navigate.url = url
  doReplace()
  return

navigator.replace = replaceThrottled = (url) ->
  url = new Url url unless url instanceof Url
  urls[navigate.index] = navigate.url = url

  now = new Date
  remaining = replaceInterval - (now - replaceLastCall)

  if remaining <= 0
    clearTimeout replaceTimeoutId if replaceTimeoutId?
    doReplace now
  else unless replaceTimeoutId?
    replaceTimeoutId = setTimeout doReplace, replaceInterval

  return

navigator.push = push = (url) ->
  url = new Url url unless url instanceof Url

  if replaceTimeoutId?
    clearTimeout replaceTimeoutId
    doReplace()

  urls[++navigate.index] = navigate.url = url

  debug "PUSH"

  if useHash
    ++ignoreCount
    iframe?.document.open().close()
    window.location.hash = url.hashHref()
    iframe?.location.href = window.location.href
  else
    window.history.pushState navigate.index, '', url.href

  return

urlchange = ->
  if ignoreCount
    --ignoreCount
  else
    if replaceTimeoutId?
      clearTimeout replaceTimeoutId
      replaceTimeoutId = null

    newUrl = new Url(window.location.href)

    if newUrl.hasHashPath()
      newIndex = newUrl.index()
      newUrl.stripHashPath()
    else unless useHash
      newIndex = window.history.state

    if !newIndex? or (newIndex is navigate.index and newUrl.href isnt navigate.url.href)
      newIndex = urls.length
      urls[newIndex] = newUrl
      replaceWith = newUrl if useHash

    if newIndex isnt navigate.index
      navigate.index = newIndex

      debug "Got url change from #{navigate.url} to #{newUrl}"

      storedUrl = urls[newIndex]

      if (replaceWith ||= if storedUrl and storedUrl.href isnt newUrl.href then storedUrl else null)
        replace replaceWith
      else
        navigate.url = urls[newIndex] = newUrl

      routeFn.call routeCtx, navigate.url.href, navigate.index

      debug "Done with urlchange"
  return

module.exports.enable = ->
  unless navigate.url

    if /msie [\w.]+/.exec(window.navigator.userAgent.toLowerCase()) and (document.documentMode || 0) <= 7
      iframe = $('<iframe src="javascript:0" tabindex="-1" />').hide().appendTo('body')[0].contentWindow
      iframe.location.href = window.location.href

    navigate.url = new Url(window.location.href)

    if useHash = !window.history || !window.history.pushState
      navigate.index = navigate.url.index()
    else
      navigate.index = window.history.state

    navigate.index ||= 0
    urls[navigate.index] = navigate.url

    navigate.url.stripHashPath() if navigate.url.hasHashPath()
    doReplace() unless useHash

    ignoreCount = 0

    if iframe
      setInterval (->
        if iframe.location.href isnt window.location.href
          window.location.href = iframe.location.href
          urlchange()
      ), 300

    else if useHash
      listen 'hashchange', urlchange
    else
      ignoreCount = 1
      listen 'popstate', urlchange

  return


module.exports.listen = (route, ctx) ->
  module.exports.enable() unless navigate.url

  unless routeFn
    routeFn = route
    routeCtx = ctx

  else
    currentRoute = routeFn
    currentRouteCtx = routeCtx

    routeCtx = null

    routeFn = (url, index) ->
      currentRoute.call currentRouteCtx, url, index
      route.call ctx, url, index
      return

  navigate
