helpers = if typeof require is 'undefined' then window.viewHelpers else require './view_helper'

QUnit.module 'Batman.View source event bindings'

asyncTest 'it should make an element focused responding to an source event', 4, ->
  source = '<div><input data-focuson-barevent="foo"></input></div>'
  context = Batman({foo: new Batman.Object()})
  helpers.render source, context, (node) ->
    delay =>
      nfocused = 0
      node[0].firstChild.focus = -> nfocused++
      equal nfocused, 0
      context.foo.fire 'barevent'
      equal nfocused, 1
      context.foo.fire 'barevent'
      equal nfocused, 2, "Event can be fired multiple times"
      context.foo.fire 'bazevent'
      equal nfocused, 2, "Unrelated events should be ignored"