open Cohttp_async
open Core

let visit_counts_table = String.Table.create () 

let get_count ?vars:(vars=String.Table.create ()) _ _ =
    let name = String.Table.find_exn vars "name" in
    String.Table.find visit_counts_table name
    |> Option.value ~default:0
    |> Printf.sprintf "Hello, %s, you have visited %d times." name
    |> Server.respond_string

let increment_count ?vars:(vars=String.Table.create ()) _ _ =
    let name = String.Table.find_exn vars "name" in
    String.Table.update visit_counts_table
                        name
                        ~f:(fun count -> Option.value count ~default:0
                                         |> (+) 1);
    Printf.sprintf "Hi %s, thanks for visiting!" name
    |> Server.respond_string ~status:`OK

let users_route =
    "/users/<name>/visits",
    [ `GET, get_count
    ; `POST, increment_count ]

let routes =
    [ users_route ]
