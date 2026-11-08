open Yocaml

(* ---------------------------------------------------------------------------
   Site configuration
   ------------------------------------------------------------------------- *)

let site_title = "Akhil Tulluri"
let site_url = "https://tulluri.me"
let site_description = "Notes on programming languages, compilers and verification."
let author = "Akhil Tulluri"

(* How many posts to show on the home page. *)
let recent_posts = 5

(* ---------------------------------------------------------------------------
   Paths
   ------------------------------------------------------------------------- *)

module Source = struct
  let content = Path.rel [ "content" ]
  let home = Path.(content / "index.md")
  let archive = Path.(content / "writing.md")
  let pages = Path.(content / "pages")
  let posts = Path.(content / "writing")
  let static = Path.rel [ "static" ]
  let templates = Path.rel [ "templates" ]
  let template file = Path.(templates / file)

  (* Rebuild everything when the generator itself changes. *)
  let binary = Path.rel [ Sys.argv.(0) ]
  let highlighter = Path.rel [ "tools"; "highlight.py" ]
end

module Target = struct
  let site = Path.rel [ "_site" ]
  let cache = Path.rel [ ".yocaml-cache" ]
  let writing = Path.(site / "writing")
  let atom = Path.(site / "atom.xml")
end

let slug file =
  match Path.(basename (remove_extension file)) with
  | Some s -> s
  | None -> failwith ("cannot compute slug for " ^ Path.to_string file)

(* content/pages/about.md -> _site/about/index.html (served as /about/) *)
let pretty_target ~into file = Path.(into / slug file / "index.html")

(* Public URL of a post. *)
let post_url file = Path.abs [ "writing"; slug file ]

(* ---------------------------------------------------------------------------
   Markdown
   ------------------------------------------------------------------------- *)

(* [strict:false] enables cmarkit's extensions: tables, footnotes,
   strikethrough, task lists and $math$ / $$math$$. *)
let markdown () = Yocaml_cmarkit.content_to_html ~strict:false ()

(* Also renders ```d2 diagrams and highlights code at build time; see render.ml. *)
let markdown_with_toc f = Render.content_to_html_with_toc f

(* ---------------------------------------------------------------------------
   Rules
   ------------------------------------------------------------------------- *)

(* Everything in static/ is copied as-is to the root of the site. *)
let static_files =
  let open Eff in
  fun cache ->
    Action.batch ~only:`Files Source.static
      (Action.copy_file ~into:Target.site)
      cache
    >>= Action.batch ~only:`Directories Source.static
          (Action.copy_directory ~into:Target.site)

let page file =
  let target =
    (* GitHub Pages / Netlify / etc. expect 404.html at the root. *)
    if slug file = "404" then Path.(Target.site / "404.html")
    else pretty_target ~into:Target.site file
  in
  let open Task in
  Action.Static.write_file_with_metadata target
    (Pipeline.track_files
       [ Source.binary; Source.highlighter; Source.template "page.html"; Source.template "layout.html" ]
    >>> Yocaml_yaml.Pipeline.read_file_with_metadata (module Archetype.Page) file
    >>> markdown_with_toc Archetype.Page.with_toc
    >>> Yocaml_jingoo.Pipeline.as_template (module Archetype.Page)
          (Source.template "page.html")
    >>> Yocaml_jingoo.Pipeline.as_template (module Archetype.Page)
          (Source.template "layout.html"))

let pages =
  Action.batch ~only:`Files ~where:(Path.has_extension "md") Source.pages page

let post file =
  let open Task in
  Action.Static.write_file_with_metadata
    (pretty_target ~into:Target.writing file)
    (Pipeline.track_files
       [ Source.binary; Source.highlighter; Source.template "post.html"; Source.template "layout.html" ]
    >>> Yocaml_yaml.Pipeline.read_file_with_metadata (module Archetype.Article) file
    >>> markdown_with_toc Archetype.Article.with_toc
    >>> Yocaml_jingoo.Pipeline.as_template (module Archetype.Article)
          (Source.template "post.html")
    >>> Yocaml_jingoo.Pipeline.as_template (module Archetype.Article)
          (Source.template "layout.html"))

let posts =
  Action.batch ~only:`Files ~where:(Path.has_extension "md") Source.posts post

let take n l = List.filteri (fun i _ -> i < n) l

(* A page (home, archive) that embeds a list of posts. *)
let index_page ~source ~target ~template ?filter () =
  let open Task in
  Action.Static.write_file_with_metadata target
    (Pipeline.track_files
       [ Source.binary
       ; Source.posts
       ; Source.template template
       ; Source.template "post-list.html"
       ; Source.template "layout.html"
       ]
    >>> Yocaml_yaml.Pipeline.read_file_with_metadata (module Archetype.Page) source
    >>> markdown ()
    >>> first
          (Archetype.Articles.compute_index
             (module Yocaml_yaml)
             ?filter
             ~where:(Path.has_extension "md")
             ~compute_link:post_url Source.posts)
    >>> Yocaml_jingoo.Pipeline.as_template (module Archetype.Articles)
          (Source.template template)
    >>> Yocaml_jingoo.Pipeline.as_template (module Archetype.Articles)
          (Source.template "layout.html"))

let home =
  index_page ~source:Source.home
    ~target:Path.(Target.site / "index.html")
    ~template:"home.html" ~filter:(take recent_posts) ()

let archive =
  index_page ~source:Source.archive
    ~target:Path.(Target.writing / "index.html")
    ~template:"writing.html" ()

let atom =
  let open Task in
  Action.Static.write_file Target.atom
    (Pipeline.track_files [ Source.binary; Source.posts ]
    >>> Archetype.Articles.fetch
          (module Yocaml_yaml)
          ~where:(Path.has_extension "md")
          ~compute_link:post_url Source.posts
    >>> Yocaml_syndication.Atom.from_articles ~site_url
          ~authors:(Nel.singleton (Yocaml_syndication.Person.make author))
          ~title:(Yocaml_syndication.Atom.text site_title)
          ~subtitle:(Yocaml_syndication.Atom.text site_description)
          ~feed_url:(site_url ^ "/atom.xml") ())

let build () =
  let open Eff in
  Action.restore_cache Target.cache
  >>= static_files
  >>= pages
  >>= posts
  >>= home
  >>= archive
  >>= atom
  >>= Action.store_cache Target.cache

let () =
  match Array.to_list Sys.argv with
  | _ :: "serve" :: rest ->
      let port =
        Option.bind (List.nth_opt rest 0) int_of_string_opt
        |> Option.value ~default:8000
      in
      Yocaml_unix.serve ~level:`Info ~target:Target.site ~port build
  | _ -> Yocaml_unix.run ~level:`Info build
