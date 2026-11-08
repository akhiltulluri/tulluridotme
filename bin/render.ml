(* Build-time rendering, so pages ship no JS for any of this.

   - ```d2 [sketch]   -> inline SVG via the `d2` CLI (https://d2lang.com)
   - ```<lang>        -> syntax-highlighted HTML via Pygments (tools/highlight.py)
   - ``` (no lang)    -> left to cmarkit (plain <pre><code>)
   - $..$ $$..$$ ```math -> KaTeX HTML via Node (tools/katex.mjs)

   Missing tools never break the build: we warn and fall back to plain code. *)

open Cmarkit

let highlighter = "tools/highlight.py"

let warn fmt = Printf.ksprintf (fun s -> prerr_endline ("[WARN] " ^ s)) fmt

let escape s =
  let b = Buffer.create (String.length s) in
  String.iter
    (function
      | '&' -> Buffer.add_string b "&amp;"
      | '<' -> Buffer.add_string b "&lt;"
      | '>' -> Buffer.add_string b "&gt;"
      | '"' -> Buffer.add_string b "&quot;"
      | c -> Buffer.add_char b c)
    s;
  Buffer.contents b

(* ---- subprocess helpers -------------------------------------------------- *)

(* Feed [input] to [prog args] on stdin and return its stdout. *)
let filter prog args input =
  match Unix.open_process_args prog (Array.of_list (prog :: args)) with
  | exception Unix.Unix_error _ -> None
  | ic, oc -> (
      output_string oc input;
      close_out oc;
      let out = In_channel.input_all ic in
      match Unix.close_process (ic, oc) with
      | Unix.WEXITED 0 -> Some out
      | _ -> None)

let read_file f = In_channel.with_open_bin f In_channel.input_all
let write_file f s = Out_channel.with_open_bin f (fun oc -> output_string oc s)

(* ---- code blocks --------------------------------------------------------- *)

let code_of cb =
  Block.Code_block.code cb |> List.map Block_line.to_string |> String.concat "\n"

(* ("d2", "sketch") for ```d2 sketch *)
let info_of cb =
  match Block.Code_block.info_string cb with
  | None -> None
  | Some (info, _) -> Block.Code_block.language_of_info_string info

let html_block s = Block.Html_block (Block_line.list_of_string s, Meta.none)

(* ---- highlighting -------------------------------------------------------- *)

(* Highlight all [(lang, code)] pairs in one Python process. *)
let highlight_all = function
  | [] -> []
  | blocks -> (
      let input =
        blocks |> List.concat_map (fun (l, c) -> [ l; c ]) |> String.concat "\000"
      in
      let fallback () = List.map (fun (_, c) -> escape c) blocks in
      match filter "python3" [ highlighter ] input with
      | Some out ->
          let frags = String.split_on_char '\000' out in
          if List.length frags = List.length blocks then frags
          else (
            warn "highlighter returned a mismatched number of blocks";
            fallback ())
      | None ->
          warn "could not run %s (is Pygments installed?)" highlighter;
          fallback ())

let code_html lang body =
  Printf.sprintf {|<pre class="highlight"><code class="language-%s">%s</code></pre>|}
    (escape lang) body

(* ---- diagrams ------------------------------------------------------------ *)

let strip_xml_prolog svg =
  if String.starts_with ~prefix:"<?xml" svg then
    match String.index_opt svg '>' with
    | Some i -> String.sub svg (i + 1) (String.length svg - i - 1)
    | None -> svg
  else svg

(* D2's outer <svg> has a viewBox but no width, so browsers stretch it to the
   container. Give it its natural size; CSS caps it at the column width. *)
let natural_size svg =
  let key = {|viewBox="|} in
  (
      let rec find i =
        if i + String.length key > String.length svg then None
        else if String.sub svg i (String.length key) = key then Some (i + String.length key)
        else find (i + 1)
      in
      match find 0 with
      | None -> svg
      | Some i -> (
          match Scanf.sscanf_opt (String.sub svg i (String.length svg - i)) "%f %f %f %f" (fun _ _ w h -> (w, h)) with
          | Some (w, h) when String.starts_with ~prefix:"<svg" svg ->
              Printf.sprintf {|<svg width="%g" height="%g"|} w h
              ^ String.sub svg 4 (String.length svg - 4)
          | _ -> svg))

(* D2 puts its dark palette in [@media (prefers-color-scheme:dark){...}] inside
   the SVG. Rewrite it so the site's light/dark toggle also applies:
     @media (...dark) { :root:not([data-theme=light]) <rule> ... }
     :root[data-theme=dark] <rule> ...                                    *)
let prefix_rules prefix body =
  String.split_on_char '}' body
  |> List.filter_map (fun rule ->
         match String.index_opt rule '{' with
         | None -> None
         | Some i ->
             let sel = String.sub rule 0 i in
             let decls = String.sub rule (i + 1) (String.length rule - i - 1) in
             let sel =
               String.split_on_char ',' sel
               |> List.map (fun s -> prefix ^ " " ^ String.trim s)
               |> String.concat ","
             in
             Some (sel ^ "{" ^ decls ^ "}"))
  |> String.concat "\n"

let toggleable_dark_mode svg =
  let key = "@media screen and (prefers-color-scheme:dark){" in
  let kl = String.length key and n = String.length svg in
  let rec find i =
    if i + kl > n then None
    else if String.sub svg i kl = key then Some i
    else find (i + 1)
  in
  let rec close i depth =
    if i >= n then None
    else
      match svg.[i] with
      | '{' -> close (i + 1) (depth + 1)
      | '}' -> if depth = 0 then Some i else close (i + 1) (depth - 1)
      | _ -> close (i + 1) depth
  in
  match find 0 with
  | None -> svg
  | Some start -> (
      match close (start + kl) 0 with
      | None -> svg
      | Some stop ->
          let body = String.sub svg (start + kl) (stop - start - kl) in
          String.sub svg 0 start
          ^ key
          ^ prefix_rules {|:root:not([data-theme="light"])|} body
          ^ "}\n"
          ^ prefix_rules {|:root[data-theme="dark"]|} body
          ^ String.sub svg (stop + 1) (n - stop - 1))

let render_d2 ~options src =
  let input = Filename.temp_file "diagram" ".d2" in
  let output = Filename.temp_file "diagram" ".svg" in
  let errors = Filename.temp_file "diagram" ".log" in
  let cleanup () = List.iter (fun f -> try Sys.remove f with _ -> ()) [ input; output; errors ] in
  write_file input src;
  let sketch = List.mem "sketch" (String.split_on_char ' ' options) in
  let args =
    [ "--theme=103"; "--dark-theme=200"; "--pad=0" ]
    @ (if sketch then [ "--sketch" ] else [])
    @ [ input; output ]
  in
  let cmd = Filename.quote_command "d2" ~stdout:Filename.null ~stderr:errors args in
  let result =
    if Sys.command cmd = 0 then
      Printf.sprintf {|<figure class="diagram">%s</figure>|}
        (toggleable_dark_mode
           (natural_size (String.trim (strip_xml_prolog (read_file output)))))
    else (
      warn "d2 failed (is it installed? https://d2lang.com):\n%s" (read_file errors);
      code_html "d2" (escape src))
  in
  cleanup ();
  result

(* ---- math ---------------------------------------------------------------- *)

let katex = "tools/katex.mjs"

(* Self-hosted KaTeX CSS + fonts (static/katex/); linked only on pages with math. *)
let katex_css = {|<link rel="stylesheet" href="/katex/katex.min.css" />|}

(* Render all [(display, tex)] pairs in one Node process. *)
let render_math_all = function
  | [] -> []
  | items -> (
      let input =
        items
        |> List.concat_map (fun (d, tex) -> [ (if d then "1" else "0"); tex ])
        |> String.concat "\000"
      in
      let fallback () =
        List.map
          (fun (d, tex) ->
            Printf.sprintf {|<code class="math">%s</code>|}
              (escape (if d then "$$" ^ tex ^ "$$" else "$" ^ tex ^ "$")))
          items
      in
      match filter "node" [ katex ] input with
      | Some out ->
          let frags = String.split_on_char '\000' out in
          if List.length frags = List.length items then frags
          else (
            warn "katex returned a mismatched number of formulas";
            fallback ())
      | None ->
          warn "could not run %s (did you run `npm ci`?)" katex;
          fallback ())

let raw_inline s = Inline.Raw_html (Block_line.tight_list_of_string s, Meta.none)

(* ---- document transform -------------------------------------------------- *)

let transform doc =
  (* Pass 1: collect code to highlight and math to typeset. *)
  let code = ref [] and math = ref [] in
  let block _ = function
    | Block.Code_block (cb, _) ->
        (match info_of cb with
        | Some (lang, _) when lang <> "d2" -> code := (lang, code_of cb) :: !code
        | _ -> ());
        Mapper.default
    | Block.Ext_math_block (cb, _) ->
        math := (true, code_of cb) :: !math;
        Mapper.default
    | _ -> Mapper.default
  in
  let inline _ = function
    | Inline.Ext_math_span (ms, _) ->
        math := (Inline.Math_span.display ms, Inline.Math_span.tex ms) :: !math;
        Mapper.default
    | _ -> Mapper.default
  in
  ignore (Mapper.map_doc (Mapper.make ~block ~inline ()) doc);
  let memo items render =
    let items = List.sort_uniq compare items in
    let table = Hashtbl.create 16 in
    List.iter2 (Hashtbl.replace table) items (render items);
    Hashtbl.find table
  in
  let has_math = !math <> [] in
  let highlighted = memo !code highlight_all in
  let typeset = memo !math render_math_all in
  (* Pass 2: replace with rendered HTML. *)
  let block _ = function
    | Block.Code_block (cb, _) -> (
        match info_of cb with
        | Some ("d2", options) ->
            Mapper.ret (html_block (render_d2 ~options (code_of cb)))
        | Some (lang, _) ->
            Mapper.ret (html_block (code_html lang (highlighted (lang, code_of cb))))
        | None -> Mapper.default)
    | Block.Ext_math_block (cb, _) ->
        Mapper.ret (html_block (typeset (true, code_of cb)))
    | _ -> Mapper.default
  in
  let inline _ = function
    | Inline.Ext_math_span (ms, _) ->
        Mapper.ret
          (raw_inline
             (typeset (Inline.Math_span.display ms, Inline.Math_span.tex ms)))
    | _ -> Mapper.default
  in
  let doc' = Mapper.map_doc (Mapper.make ~block ~inline ()) doc in
  if not has_math then doc'
  else
    Doc.make ~defs:(Doc.defs doc')
      (Block.Blocks ([ html_block katex_css; Doc.block doc' ], Meta.none))

(* ---- YOCaml arrows ------------------------------------------------------- *)

(* Like [Yocaml_cmarkit.content_to_html_with_toc], with [transform] applied. *)
let content_to_html_with_toc f =
  let open Yocaml.Task in
  second
    (Yocaml_cmarkit.to_doc ~strict:false ()
    >>> lift transform
    >>> Yocaml_cmarkit.table_of_contents
    >>> second (Yocaml_cmarkit.from_doc_to_html ()))
  >>> lift (fun (meta, (toc, html)) -> (f meta toc, html))
