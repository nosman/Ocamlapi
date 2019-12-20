open Async
open Core
open Cohttp_async

let exn_handler ?vars:_ _ =
        Server.respond_string ~status:(`Code 500) "Internal server error" 

let greeting_route =
    "/<name>/greet",
    [`GET, fun ?vars:(vars=String.Table.create ()) _request _body ->
                String.Table.find_exn vars "name"
                |> Printf.sprintf "Hello, %s!"
                |> Server.respond_string ]

let r = Ocamlapi_async.create_exn ~exn_handler:exn_handler [ greeting_route ] 

let handler ~body:b _sock req =
    Ocamlapi_async.dispatch r req b

let start_server port () =
    eprintf "Listening for HTTP on port %d\n" port;
    Cohttp_async.Server.create
                        ~on_handler_error:`Ignore
                        (Async.Tcp.Where_to_listen.of_port port)
                        handler
                        >>= fun _ -> Deferred.never ()

let () =
    let module Command = Async.Command in
        Command.async_spec
                ~summary:"Start a hello world Async server"
                Command.Spec.(
                        empty +>
                        flag "-p" (optional_with_default 8080 int)
                                ~doc:"int Source port to listen on"
                ) start_server
        |> Command.run
