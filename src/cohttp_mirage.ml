(*
 * Copyright (c) 2012-2015 Anil Madhavapeddy <anil@recoil.org>
 * Copyright (c) 2013-2015 Thomas Gazagnaire <thomas@gazazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 * mirage-http 2.5.3
 *)

open Lwt.Infix

module Client = struct

  module Channel = Channel.Make(Conduit_mirage.Flow)
  module HTTP_IO = Cohttp_mirage_io.Make(Channel)

  module Net_IO = struct

    module IO = HTTP_IO

    type ctx = {
      resolver: Resolver_lwt.t;
      conduit : Conduit_mirage.t;
    }

    let sexp_of_ctx { resolver; _ } = Resolver_lwt.sexp_of_t resolver

    let default_ctx =
      { resolver = Resolver_mirage.localhost; conduit = Conduit_mirage.empty }

    let connect_uri ~ctx uri =
      Resolver_lwt.resolve_uri ~uri ctx.resolver >>= fun endp ->
      Conduit_mirage.client endp >>= fun client ->
      Conduit_mirage.connect ctx.conduit client >>= fun flow ->
      let ch = Channel.create flow in
      Lwt.return (flow, ch, ch)

    let close_in _ = ()
    let close_out _ = ()
    let close ic _oc = Lwt.ignore_result (Channel.close ic)

  end
  let ctx resolver conduit = { Net_IO.resolver; conduit }

  (* Build all the core modules from the [Cohttp_lwt] functors *)
  include Cohttp_lwt.Make_client(HTTP_IO)(Net_IO)

end

module Server (Flow: V1_LWT.FLOW) = struct

  module Channel = Channel.Make(Flow)
  module HTTP_IO = Cohttp_mirage_io.Make(Channel)
  include Cohttp_lwt.Make_server(HTTP_IO)

  let listen spec flow =
    let ch = Channel.create flow in
    Lwt.finalize
      (fun () -> callback spec flow ch ch)
      (fun () -> Channel.close ch)

end

module Server_with_conduit = struct

  include Server(Conduit_mirage.Flow)

  let connect t =
    let listen s f = Conduit_mirage.listen t s (listen f) in
    Lwt.return (`Ok listen)

end
