# Ocamlapi

Ocamlapi is an Ocaml library for path-based routing of HTTP requests.

Full documentation is available [here](https://nosman.github.io/Ocamlapi/).

It is built on top of [Cohttp](https://github.com/mirage/ocaml-cohttp).

## Libraries

The core of Ocamlapi is parameterized on your choice of Http library.

Ocamlapi has 4 separately installable libraries:

* [ocamlapi](https://opam.ocaml.org/packages/ocamlapi/): Core functors for the library.
* [ocamlapi_async](https://opam.ocaml.org/packages/ocamlapi_async/): An implementation of ocamlapi using the `Cohttp-async` backend.
* [ocamlapi_lwt_unix](https://opam.ocaml.org/packages/ocamlapi_lwt_unix/): An implmentation of ocamlapi using the `Cohttp-lwt-unix` backend.
* [ocamlapi_ppx](https://opam.ocaml.org/packages/ocamlapi_ppx/): Syntax extensions. These eliminate boilerplate when creating routes.

Each library is installable through [opam](https://opam.ocaml.org/):

EG. to install `ocamlapi_async`, run `opam install ocamlapi_async`.

## Getting Started

Ocamlapi allows the user to build routers, which bind callbacks to URLs.
When a request is received by the server, a router is used to dispatch the request to
the appropriate callback.

### URL templates

A URL template specifies a set of URLs to be matched against.

A URL template consists of a list of path segments delimited by forward slashes.
A path segment can either be static or dynamic. A static path segment matches against a
single string. A dynamic path segment matches against any string up to the next forward slash
in the path, and is written as `<variable name>`.

A few examples of URL templates:

`/api/version`
    This matches against the literal string `/api/version`

`/users/<userId>`
    This matches agasint strings such as `/users/sam`.
    It does not match against strings such as `/users/sam/history`.

`/users/<userId>/profile`
    This matches against strings such as `/users/sam/profile`.

### Routes

A route consists of a URL template and a list of tuples. Each tuple in the list is of the form
`(HTTP method, callback)`. This means that the route will match any request where the path matches
the route's URL template, and the request's HTTP method appears in the list.

The callback associated with the HTTP method then gets called on the request.

### Callbacks

A callback is a function of type
`?⁠vars:string Core.String.Table.t ‑> request -> body -> (response * body) io`

The first argument to a callback is an optional map of strings to strings.
This map's keys are the names of the dynamic path segments in the URL template that was matched.
The corresponding values are the values that were extracted from the request's path.

For example, if a route is declared as
`"/user/<userId>", [ `GET, some_callback]`
and a GET request is made to the path `"/user/sam"`, the map given to the callback will have a single key,
`"userId"`, and its value will be `"sam"`.

The second argument is the request that was made to the server.
The third argument is the request's body.

Finally, a callback returns an HTTP response and its body asynchronously, hence the return type of
`(response * body) io`.

The callback contains whatever business logic necessary to power the response. For example, within a callback,
you can make database calls, call a template rendering libary, etc.

### Routers

A router is the data structure that actually dispatches the request to the appropriate callback.

#### Creating a router

A router has 3 main components: a list of routes, a fallback function, and an error handling function.

The fallback function is a callback that gets called when no route matches the given request.
The error handler is a function that gets called if a callback throws an exception while processing a request.
Finally, the list of routes defines what routes a router will respond to.

#### Routing a request

The `dispatch` function takes a router and a request, and routes the request to the appropriate callback.

### Using vanilla Ocamlapi

We will use `Ocamlapi_async` for this introduction.

Here is an example of a server that supports a single GET operation on the path:
`/<name>/greet`:

```ocaml
open Async
open Core
open Cohttp_async
open Ocamlapi_async

(* Declare a route *)
let greeting_route =
    "/<name>/greet",
    [`GET, fun args _request _body ->
                Rule.RouteArgSet.find_exn args "name"
                |> Printf.sprintf "Hello, %s!"
                |> Server.respond_string ]

let exn_handler _ =
    Server.respond_string ~status:(`Code 500) "Internal server error"

(* Declare the router *)
let r = Ocamlapi_router.create_exn [ greeting_route ] exn_handler

let handler ~body:b _sock req =
    (* Dispatch a request to a route *)
    Ocamlapi_router.dispatch r req b

let start_server port () =
    eprintf "Listening for HTTP on port %d\n" port;
    Cohttp_async.Server.create
                        ~on_handler_error:`Ignore
                        (Async.Tcp.Where_to_listen.of_port port)
                        handler
                        >>= fun _ -> Deferred.never ()

let () =
    let module Command = Async_extra.Command in
        Command.async_spec
                ~summary:"Start a hello world Async server"
                Command.Spec.(
                        empty +>
                        flag "-p" (optional_with_default 8080 int)
                                ~doc:"int Source port to listen on"
                ) start_server
        |> Command.run

```

For documentation around the server component of this example, consult the
[Cohttp](https://github.com/mirage/ocaml-cohttp) project.

### Using the syntax extensions

The syntax extensions in the `Ocamlapi_ppx` ppx rewriter offer a more convenient,
declarative syntax to declare routes and routers.

```ocaml

module Counter_routes = struct

  let counter = ref 0

  let%route "/counter" =
    [ `GET, fun args _req _body ->
              !counter
              |> string_of_int
              |> Server.respond_string ]

  let%route "/counter/increment" =
    [ `POST, fun args _req _body ->
               counter := !counter + 1;
               `Code 200
               |> Server.respond ]

  let%route "/counter/decrement" =
    [ `POST, fun args _req _body ->
               counter := !counter - 1;
               `Code 200
               |> Server.respond ]

end

let exn_handler _ =
    Server.respond_string ~status:(`Code 500) "Internal server error"

let%router r = [ Counter_routes ], exn_handler

```

Here, a route is declared with the url path on the left, and a list of
(HTTP method, callback) pairs on the right. *Note*: any expression with the correct type can be used as the callback. The callback doesn't necessarily have to be a lambda as in this example.

The router declaration takes a list of module names with routes declared within
them.
