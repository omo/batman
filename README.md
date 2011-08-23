# batman.js

[batman.js](http://batmanjs.org/) is a framework for building rich single-page browser applications. It is written in [CoffeeScript](http://jashkenas.github.com/coffee-script/) and its API is developed with CoffeeScript in mind, but of course you can use plain old JavaScript too.

It's got:

* a stateful MVC architecture
* a powerful binding system
* routable controller actions
* pure HTML views
* toolchain support built on [node.js](http://nodejs.org) and [cake](http://jashkenas.github.com/coffee-script/#cake)

We're targeting Chrome, Safari 4+, Firefox 3+, and IE 7+ for compatibility, although some of those require you to include [es5shim](https://github.com/kriskowal/es5-shim).


## Installation

If you haven't already, you'll need to install [node.js](http://nodejs.org) and [npm](http://npmjs.org/). Then:

    npm install -g batman

Generate a new batman.js app somewhere, called my_app:

    cd ~/code
    batman new my_app

Fire it up:

    cd my_app
    batman server # (or just "batman s")

Now visit [http://localhost:8124](http://localhost:8124) and start playing around!

## The Basics

Most of the classes you work with in your app code will descend from `Batman.Object`, which gives you some nice things that are used extensively by the rest of the system.

### Events

If you want to define observable events on your objects, just wrap a function with the `@event` macro in a class definition:

    class Gadget extends Batman.Object
      constructor: -> @usesLeft = 5
      use: @event (times) ->
        return false unless (@usesLeft - times) >= 0
        @usesLeft -= times
    
You can observe the event with some callback, and fire it by just calling the event function directly. The observer callback gets whichever arguments were passed into the event function. But if the even function returns `false`, then the observers won't fire:
    
    gadget.observe 'use', (times) ->
      console.log "gadget was used #{times} times!"
    gadget.use(2)
    # console output: "gadget was used 2 times!"
    gadget.use(6)
    # nothing happened!
      

### Observable Properties

The `observe` function is also used to observe changes to properties. This forms the basis of the binding system. Here's a simple example:

    gadget.observe 'name', (newVal, oldVal) ->
      console.log "name changed from #{oldVal} to #{newVal}!"
    gadget.set 'name', 'Batarang'
    # console output: "name changed from undefined to Batarang!"

You can also `get` properties to return their values, and if you want to remove them completely then you can `unset` them:
    
    gadget.get 'name'
    # returns: 'Batarang'
    gadget.unset 'name'
    # console output: "name changed from Batarang to undefined!"

By default, these properties are stored like plain old JavaScript properties: that is, `gadget.name` would return "Batarang" just like you'd expect. But if you set the gadget's name with `gadget.name = 'Shark Spray'`, then the observer function you set on `gadget` will not fire. So when you're working with batman.js properties, use `get`/`set`/`unset` to read/write/delete properties (unless you )


### Custom Accessors

What's the point of using `gadget.get 'name'` instead of just `gadget.name`? Well, a Batman properties doesn't need to correspond with a vanilla JS property. Let's write a `Box` class with a custom getter for its volume:

    class Box extends Batman.Object
      constructor: (@length, @width, @height) ->
      @accessor 'volume',
        get: (key) -> @get('length') * @get('width') * @get('height')
    
    box = new Box(16,16,12)
    box.get 'volume'
    # returns 3072

The really cool thing about this is that, because we used `@get` to access the component properties of `volume`, batman.js can keep track of those dependencies and let us observe the `volume` directly:
    
    box.observe 'volume', (newVal, oldVal) ->
      console.log "volume changed from #{oldVal} to #{newVal}!"
    box.set 'height', 6
    # console output: "volume changed from 3072 to 1536!"

The box's `volume` is a read-only attribute here, because we only provided a getter in the accessor we defined. Here's a `Person` class with a (rather naive) read-write accessor for their name:

    class Person extends Batman.Object
      constructor: (name) -> @set 'name', name
      @accessor 'name',
        get: (key) -> [@get('firstName'), @get('lastName')].join(' ')
        set: (key, val) ->
          [first, last] = val.split(' ')
          @set 'firstName', first
          @set 'lastName', last
        unset: (key) ->
          @unset 'firstName'
          @unset 'lastName'
          
          
### Keypaths

If you want to get at properties of properties, use keypaths:

    employee.get 'team.manager.name'

This does what you expect and is pretty much the same as `employee.get('team').get('manager').get('name')`. If you want to observe a deep keypath for changes, go ahead:
    
    employee.observe 'team.manager.name', (newVal, oldVal) ->
      console.log "you now answer to #{newVal || 'nobody'}!"
    manager = employee.get 'team.manager'
    manager.set 'name', 'Bill'
    # console output: "you now answer to Bill!"

If any component of the keypath is set to something that would change the overall value, then observers will fire:
    
    employee.set 'team', larrysTeam
    # console output: "you now answer to Larry!"
    employee.team.unset 'manager'
    # console output: "you now answer to nobody!"
    employee.set 'team', jessicasTeam
    # console output: "you now answer to Jessica!"
    
batman.js's dependency tracking system makes sure that no matter how weird your object graph gets, your observers will fire exactly when they should.


## Architecture

The MVC architecture of batman.js fits together like this:

* Controllers are persistent objects which render the views and give them mediated access to the model layer.
* Views are written in pure HTML, and use `data-*` attributes to create bindings with model data and event handlers exposed by the controllers.
* Models have validations, lifecycle events, a built-in identity map, and can use arbitrary storage backends (`Batman.LocalStorage` and `Batman.RestStorage` are included).

A batman.js application is served up in one page load, followed by asynchronous requests for various resources as the user interacts with the app. Navigation within the app is handled via [hash-bang fragment identifers](http://www.w3.org/QA/2011/05/hash_uris.html), with [pushState](https://developer.mozilla.org/en/DOM/Manipulating_the_browser_history#Adding_and_modifying_history_entries) support forthcoming.


### Controllers

batman.js controllers are singleton classes with one or more instance methods that can serve as routable actions. Because they're singletons, instance variables persist as long as the app is running. You normally define your routes along with your actions, like so:

    class MyApp.UsersController extends Batman.Controller
      index: @route('/users') ->
        @users ||= MyApp.User.get('all')

Now when you navigate to `/#!/users`, the dispatcher runs this `index` action with an implicit call to `@render`, which by default will look for a view at `/views/users/index.html`. The view is rendered within the main content container of the page, which is designated by setting `data-yield="main"` on some tag in the layout's HTML.

Controllers are also a fine place to put event handlers used by your views. Here's one that uses [jQuery](http://jquery.com/) to toggle a CSS class on a button:

    class MyApp.BigRedButtonController extends Batman.Controller
      index: @route('/button') ->
      
      buttonWasClicked: (node, event) ->
        $(node).toggleClass('activated')

### Views

You write views in plain HTML. These aren't templates in the usual sense: the HTML is rendered in the page as-is, and you use `data-*` attributes to specify how different parts of the view bind to your app's data. Here's a very small view which displays a user's name and avatar:

    <div class="user">
      <img data-bind-src="user.avatarURL" />
      <p data-bind="user.name"></p>
    </div>

The `data-bind` attribute on the `<p>` tag sets up a binding between the user's `name` property and the content of the tag. The `data-bind-src` attribute on the `<img>` tag binds the user's `avatarURL` property to the `src` attribute of the tag. You can do the same thing for arbitrary attribute names, so for example `data-bind-href` would bind to the `href` attribute.

batman.js uses a bunch of these data attributes for different things:

#### Binding properties

* `data-bind="foo.bar"`: for most tags, this defines a one-way binding with the contents of the node: when the given property `foo.bar` changes, the contents of the node are set to that value. When `data-bind` is set on a form input tag, a _two-way_ binding is defined with the _value_ of the node, such that any changes from the user will update the property in realtime.

* `data-bind-foo="bar.baz"`: defines a one-way binding from the given property `bar.baz` to any attribute `foo` on the node.

* `data-foreach-bar="foo.bars"`: used to render a collection of zero or more items. If the collection descends from `Batman.Set`, then the DOM will be updated when items are added, removed. If it's a descendent of `Batman.SortableSet`, then its current sort.

#### Handling DOM events

* `data-event-click="foo.bar"`: when this node is clicked, the function specified by the keypath `foo.bar` is called with the node object as the first argument, and the click event as the second argument.

* `data-event-change="foo.bar"`: like `data-event-click`, but fires on change events.

* `data-event-submit="foo.bar"`: like `data-event-click`, but fires either when a form is submitted (in the case of `<form>` nodes) or when a user hits the enter key when an `<input>` or `<textarea>` has focus.

#### Managing contexts

* `data-context="foo.bar"`: pushes a new context onto the context stack for children of this node. If the context is `foo.bar`, then children of this node may access properties on `foo.bar` directly, as if they were properties of the controller.
  
#### Rendering Views

* `data-yield="identifier"`: used in your layout to specify the locations that other views get rendered into when they are rendered. By default, a controller action renders each whole view into whichever node is set up to yield `"main"`. If you want some content in a view to be rendered into a different `data-yield` node, you can use `data-contentfor`.

* `data-contentfor="identifier"`: when the view is rendered into your layout, the contents of this node will be rendered into whichever node has `data-yield="identifier"`. For example, if your layout has `"main"` and `"sidebar"` yields, then you may put a `data-contentfor="sidebar"` node in a view and it will be rendered in the sidebar instead of the main content area.

* `data-partial="/views/shared/sidebar"`: renders the view at the path `/views/shared/sidebar.html` within this node.


### Models

batman.js models:

* can persist to various storage backends
* only serialize a defined subset of their properties as JSON
* use a state machine to expose lifecycle events
* can validate with synchronous or asynchronous operations

#### Attributes

A model object may have arbitrary properties set on it, just like any JS object. Only some of those properties are serialized and persisted to its storage backends, however. You define persisted attributes on a model with the `encode` macro:

    class Article extends Batman.Model
      @encode 'body_html', 'title', 'author', 'summary_html', 'blog_id', 'id', 'user_id'
      @encode 'created_at', 'updated_at', 'published_at',
        encode: (time) -> time.toISOString()
        decode: (timeString) -> Date.parse(timeString)
      @encode 'tags',
        encode: (tagSet) -> tagSet.toArray().join(', ')
        decode: (tagString) -> new Batman.Set(tagString.split(', ')...)

Given one or more strings as arguments, `@encode` will register these properties as persisted attributes of the model, to be serialized in the model's `toJSON()` output and extracted in its `fromJSON()`. Properties that aren't specified with `@encode` will be ignored for both serialization and deserialization. If an optional coder object is provided as the last argument, its `encode` and `decode` functions will be used by the model for serialization and deserialization, respectively.

By default, a model's primary key (the unchanging property which uniquely indexes its instances) is its `id` property. If you want your model to have a different primary key, specify it with the `@id` macro:

    class User extends Batman.Model
      @encode 'handle', 'email'
      @id 'handle'

#### States

* `empty`: a new model instance remains in this state until some persisted attribute is set on it.
* `loading`: entered when the model instance's `load()` method is called.
* `loaded`: entered after the model's storage adapter has completed loading updated attributes for the instance. Immediately transitions to the `clean` state.
* `dirty`: entered when one of the model's persisted attributes changes.
* `validating`: entered when the validation process has started.
* `validated`: entered when the validation process has completed. Immediately after entering this state, the model instance transitions back to either the `dirty` or `clean` state.
* `saving`: entered when the storage adapter has begun saving the model.
* `saved`: entered after the model's storage adapter has completed saving the model. Immediately transitions to the `clean` state.
* `clean`: indicates that none of an instance's attributes have been changed since the model was `saved` or `loaded`.
* `destroying`: entered when the model instance's `destroy()` method is called.
* `destroyed`: indicates that the storage adapter has completed destroying this instance.

#### Validation

Before models are saved to persistent storage, they run through any validations you've defined and the save is cancelled if any errors were added to the model during that process.

Validations are defined with the `@validate` macro by passing it the properties to be validated and an options object representing the particular validations to perform:

    class User extends Batman.Model
      @encode 'login', 'password'
      @validate 'login', presence: yes, maxLength: 16
      @validate 'password', 'passwordConfirmation', presence: yes, lengthWithin: [6,255]
      
The options get their meaning from subclasses of `Batman.Validator` which have been registered by adding them to the `Batman.Validators` array. For example, the `maxLength` and `lengthWithin` options are used by `Batman.LengthValidator`.


#### Persistence

To specify a storage adapter for persisting a model, use the `@persist` macro in its class definition:

    class Product extends Batman.Model
      @persist Batman.LocalStorage

Now when you call `save()` or `load()` on a product, it will use the browser window's [localStorage](https://developer.mozilla.org/en/dom/storage) to retrieve or store the serialized data.

If you have a REST backend you want to connect to, `Batman.RestStorage` is a simple storage adapter which can be subclassed and extended to suit your needs. By default, it will assume your CamelCased-singular `Product` model is accessible at the underscored-pluralized "/products" path, with instances of the resource accessible at `/products/:id`. You can override these path defaults by assigning either a string or a function-returning-a-string to the `url` property of your model class (for the collection path) or to the prototype (for the member path). For example:

    class Product extends Batman.Model
      @persist Batman.RestStorage
      @url = "/admin/products"
      url: -> "/admin/products/#{@id}"


# Contributing

Well-tested contributions are always welcome! Here's what you should do:

#### 1. Clone the repo

    git clone https://github.com/Shopify/batman.git

#### 2. Run the tests

You can test batman.js locally either on the command line or in the browser and both should work. Tests are written in Coffeescript using [QUnit](http://docs.jquery.com/QUnit#API_documentation).

To run on the command line, run the following command from the project root:

    cake test

To run in the browser (so you can interactively debug perhaps), start a web server to serve up the tests:

    batman server

...then visit `http://localhost:8124/test/batman/test.html` in your browser.

#### 3. Write some test-driven code

The tests are in `tests/batman`. You'll need to source any new test files in `tests/batman/test.html`.

#### 4. Create a pull request

If it's good code that fits with the goals of the project, we'll merge it in!

# License

batman.js is copyright 2011 by [Shopify](http://www.shopify.com), released under the MIT License (see LICENSE for details).


