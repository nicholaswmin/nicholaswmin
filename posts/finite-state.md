# finite-state machine

2023-12-10

[![tests][testb]][tests] [![ccovt][cocov]](#tests)

> A [finite-state machine][fsm]  
>
> ... is an abstract machine that can be in one of a finite number of states.    
> The change from one `state` to another is called a `transition`.

This package constructs simple FSM's which express their logic 
declaratively & safely.[^1]
  
`~1KB`, zero dependencies, [opinionated][dgoals]  

### Basic

- [Install](#install)
- [Example](#example)
  - [Initialisation](#initialisation)
  - [Transition](#transition)
  - [Current state](#current-state)

### Extras

- [Hooks](#hook-methods)
- [Transition cancellations](#transition-cancellations)
- [Asynchronous transitions](#asynchronous-transitions)
- [Serialising to JSON](#serialising-to-json)
- [As a mixin](#fsm-as-a-mixin)

### API

- [`fsm(states, hooks)`](#fsmstates-hooks)
- [`fsm(json, hooks)`](#fsmjson-hooks)
- [`fsm.state`](#fsmstate)

### Meta

- [Tests](#tests)
- [Publishing](#publishing)
- [Authors](#authors)
- [License](#license)

## Install 

```bash
npm i @nicholaswmin/fsm
```

## Example

> A [turnstile][turn] gate that opens with a coin.  
> When opened you can push through it; after which it closes again:

```js
import { fsm } from '@nicholaswmin/fsm'

// define states & transitions:

const turnstile = fsm({
  closed: { coin: 'opened' },
  opened: { push: 'closed' }
})

// transition: coin
turnstile.coin()
// state: opened

// transition: push
turnstile.push()
// state: closed

console.log(turnstile.state)
// "closed"
```

Each step is broken down below.

## Initialisation

An FSM with 2 possible `states`, each listing a single `transition`:

```js
const turnstile = fsm({
  closed: { coin: 'opened' },
  opened: { push: 'closed' }
})
```

- `state: closed`: allows `transition: coin` which sets: `state: opened`
- `state: opened`: allows `transition: push` which sets: `state: closed`

## Transition

A `transition` can be called as a method:

```js
const turnstile = fsm({
  // defined 'coin' transition
  closed: { coin: 'opened' },

  // defined 'push' transition
  opened: { push: 'closed' }
})

turnstile.coin()
// state: opened

turnstile.push()
// state: closed
```

The current `state` must list the transition, otherwise an `Error` is thrown:

```js
const turnstile = fsm({
  closed: { coin: 'opened' },
  opened: { push: 'closed' }
})

turnstile.push()
// TransitionError: 
// current state: "closed" has no transition: "push"
```

## Current state

The `fsm.state` property indicates the current `state`:

```js
const turnstile = fsm({
  closed: { foo: 'opened' },
  opened: { bar: 'closed' }
})

console.log(turnstile.state)
// "closed"
```

## Hook methods

Hooks are optional methods, called at specific transition phases.  

They must be set as `hooks` methods; an `Object` passed as 2nd argument of 
`fsm(states, hooks)`.

### Transition hooks

Called *before* the state is changed & can optionally 
[cancel a transition](#transition-cancellations).

Must be named: `on<transition-name>`, where `<transition-name>` is an actual 
`transition` name.

```js
const turnstile = fsm({
  closed: { coin: 'opened' },
  opened: { push: 'closed' }
}, {
  onCoin: function() {
    console.log('got a coin')
  },
  
  onPush: function() {
    console.log('got pushed')
  }
})

turnstile.coin()
// "got a coin"

turnstile.push()
// "got pushed"
```

### State hooks

Called *after* the state is changed.

Must be named: `on<state-name>`, where `<state-name>` is an actual `state` name.

```js
const turnstile = fsm({
  closed: { coin: 'opened' },
  opened: { push: 'closed' }
}, {
  onOpened: function() {
    console.log('its open')
  },

  onClosed: function() {
    console.log('its closed')
  }
})

turnstile.coin()
// "its open"

turnstile.push()
// "its closed"
```

### Hook arguments 

Transition methods can pass arguments to relevant hooks, assumed to be
variadic: [^2]

```js
const turnstile = fsm({
  closed: { coin: 'opened' },
  opened: { push: 'closed' }
}, {
  onCoin(one, two) {
    return console.log(one, two)
  }
})

turnstile.coin('foo', 'bar')
// foo, bar
```

## Transition cancellations

[Transition hooks](#transition-hooks) can cancel the transition by returning 
`false`.

Cancelled transitions don't change the *state* nor call any 
[state hooks](#state-hooks).

> example: cancel transition to `state: opened` if the coin is less than `50c`

```js
const turnstile = fsm({
  closed: { coin: 'opened' },
  opened: { push: 'closed' }
}, {
  onCoin(coin) {
    return coin >= 50
  }
})

turnstile.coin(30)
// state: closed

// state still "closed",

// add more money?

turnstile.coin(50)
// state: opened
```

> note: must explicitly return `false`, not just [`falsy`][falsy].

## Asynchronous transitions

Mark relevant hooks as [`async`][async] and [`await`][await] the transition:

```js
const turnstile = fsm({
  closed: { coin: 'opened' },
  opened: { push: 'closed' }
}, {
  async onCoin(coins) {
    // simulate something async
    await new Promise(res => setTimeout(res.bind(null, true), 2000))
  }
})

await turnstile.coin()
// 2 seconds pass ...

// state: opened
```

## Serialising to JSON

Simply use [`JSON.stringify`][JSON.stringify]:

```js
const hooks = {
  onCoin() { console.log('got a coin') }
  onPush() { console.log('pushed ...') }
}

const turnstile = fsm({
  closed: { coin: 'opened' },
  opened: { push: 'closed' }
}, hooks)

turnstile.coin()
// got a coin

const json = JSON.stringify(turnstile)
```

... then revive with:

```js
const revived = fsm(json, hooks)
// state: opened 

revived.push()
// pushed ..
// state: closed
```

> note: `hooks` are not serialised so they must be passed again when reviving, 
> as shown above.

## FSM as a `mixin`

Passing an `Object` as `hooks` to: `fsm(states, hooks)` assigns FSM behaviour 
on the provided object.

Useful in cases where an object must function as an FSM, in addition to some 
other behaviour.[^3]

> example: A `Turnstile` functioning as both an [`EventEmitter`][ee] & an `FSM`

```js
class Turnstile extends EventEmitter {
  constructor() {
    super()

    fsm({
      closed: { coin: 'opened' },
      opened: { push: 'closed' }
    }, this)
  }
}

const turnstile = new Turnstile()

// works as EventEmitter.

turnstile.emit('foo')

// works as an FSM as well.

turnstile.coin()

// state: opened
```

> this concept is similar to a [`mixin`][mixin].


## API

### `fsm(states, hooks)`

Construct an `FSM`

| name     | type     | desc.                           | default  |
|----------|----------|---------------------------------|----------|
| `states` | `object` | a [state-transition table][stt] | required |
| `hooks`  | `object` | implements transition hooks     | `this`   |

`states` must have the following abstract shape:

```js
state: { 
  transition: 'next-state',
  transition: 'next-state' 
},
state: { transition: 'next-state' }
```

- The 1st state in `states` is set as the *initial* state.    
- Each `state` can list zero, one or many transitions.   
- The `next-state` must exist as a `state`.  

### `fsm(json, hooks)` 

Revive an instance from it's [JSON][json].   

#### Arguments

| name     | type     | desc.                         | default  |
|----------|----------|-------------------------------|----------|
| `json`   | `string` | `JSON.stringify(fsm)` result  | required |

### `fsm.state` 

The current `state`. Read-only.    

| name     | type     | default       |
|----------|----------|---------------|
| `state`  | `string` | current state | 

## Tests

> unit tests:

```bash
node --run test
```

> these tests *require* that certain [coverage thresholds][ccov-thresh] are met.

## Contributing

[Contribution Guide][contr-guide]

## Publishing 

- collect all changes in a pull-request
- merge to `main` when all ok

then from a clean `main`:

```bash
# list current releases
gh release list
``` 

Choose the next [Semver][semver], i.e: `1.3.1`, then:

```bash
gh release create 1.3.1
```

> **note:** dont prefix releases/tags with `v`, just `x.x.x` is enough.

The Github release triggers the [`npm:publish workflow`][npmpubworkflow],  
publishing the new version to [npm][npmproj].  

It then attaches a [Build Provenance][provenance] statement on the 
[Release Notes][rel-notes].

That's all.
  
## Authors

[N.Kyriakides; @nicholaswmin][author]

## License 

The [MIT License][license]

### Footnotes 

[^1]: A finite-state machine can only exist in *one* and *always-valid* state.  
      It requires declaring all possible states & the rules under which it can 
      transition from one state to another.  

[^2]: A function that accepts an infinite number of arguments.   
      Also called: functions of *"n-arity"* where "arity" = number of arguments. 
      
      i.e: nullary: `f = () => {}`, unary: `f = x => {}`,
      binary: `f = (x, y) => {}`, ternary `f = (a,b,c) => {}`, 
      n-ary/variadic: `f = (...args) => {}`
      
[^3]: FSMs are rare but perfect candidates for *inheritance* because usually
      something `is-an` FSM.  
      However, Javascript doesn't support *multiple inheritance* so inheriting 
      `FSM` would create issues when inheriting other behaviours.

      *Composition* is also problematic since it namespaces the behaviour, 
      causing it to lose it's expressiveness.  
      i.e `light.fsm.turnOn` feels misplaced compared to `light.turnOn`.
      

[testb]: https://github.com/nicholaswmin/fsm/actions/workflows/tests:unit.yml/badge.svg
[tests]: https://github.com/nicholaswmin/fsm/actions/workflows/tests:unit.yml
[cocov]: https://img.shields.io/badge/coverage-%3E%2095%25-blue
[ccovt]: https://github.com/nicholaswmin/fsm/blob/6db5c1c5ede6edb15cb1b8431a4716163a7410d4/package.json#L11

[turn]: https://en.wikipedia.org/wiki/Finite-state_machine#Example:_coin-operated_turnstile
[fsm]: https://en.wikipedia.org/wiki/Finite-state_machine
[stt]: https://en.wikipedia.org/wiki/State-transition_table
[dfsm]: https://en.wikipedia.org/wiki/Deterministic_finite_automaton
[automata]: https://en.wikipedia.org/wiki/Automata_theory
[mixin]: https://developer.mozilla.org/en-US/docs/Glossary/Mixin
[alternatives]: https://www.npmjs.com/search?q=fsm
[async]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/async_function
[await]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/await
[promise]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise
[JSON.stringify]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON/stringify
[json]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON
[mixin]: https://developer.mozilla.org/en-US/docs/Glossary/Mixin
[falsy]: https://developer.mozilla.org/en-US/docs/Glossary/Falsy
[ee]: https://nodejs.org/docs/latest/api/events.html#class-eventemitter

[npmproj]: https://www.npmjs.com/package/@nicholaswmin/fsm
[semver]: https://semver.org/
[npmpubworkflow]: https://github.com/nicholaswmin/fsm/actions/workflows/npm:publish.yml
[provenance]: https://docs.npmjs.com/generating-provenance-statements/
[rel-notes]: https://github.com/nicholaswmin/fsm/releases/latest

[prov]: https://search.sigstore.dev/?logIndex=136020643
[contr-guide]: https://github.com/nicholaswmin/fsm/blob/main/.github/CONTRIBUTING.md
[ccov-thresh]: https://github.com/nicholaswmin/fsm/blob/main/package.json#L11
[dgoals]: https://github.com/nicholaswmin/fsm/blob/main/.github/CONTRIBUTING.md#design-goals
[author]: https://github.com/nicholaswmin
[license]: https://raw.githubusercontent.com/nicholaswmin/fsm/refs/heads/main/LICENSE
